#!/bin/bash
set -euo pipefail
RESOURCES="$(cd "$(dirname "$0")" && pwd -P)"
SUPPORT="$HOME/Library/Application Support/RiseOnAir"
ENGINE="$SUPPORT/engine"
STATE="$SUPPORT/DreamSkin"
ACTION="${1:-launch}"
phase() { printf '%s action=%s %s\n' "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" "$ACTION" "$1"; }
safe_path() {
  local p="$1"
  while [ "$p" != / ] && [ -n "$p" ]; do
    [ ! -L "$p" ] || { printf '拒绝写入符号链接路径：%s\n' "$p" >&2; exit 1; }
    p="$(/usr/bin/dirname "$p")"
  done
}
safe_path "$SUPPORT"
LOGIN_PLIST="$HOME/Library/LaunchAgents/io.github.qt0713.riseonair.login.plist"
xml_escape() { /usr/bin/sed -e 's/\&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
register_login() {
  safe_path "$LOGIN_PLIST"
  if [ -f "$LOGIN_PLIST" ]; then
    /usr/bin/grep -q '<key>RiseOnAirManaged</key>' "$LOGIN_PLIST" || { printf '登录项路径已由其他文件占用。\n' >&2; return 1; }
  fi
  /bin/mkdir -p "$(/usr/bin/dirname "$LOGIN_PLIST")"
  local executable log staged
  executable="$(printf '%s' "${RESOURCES%/Resources}/MacOS/RiseOnAir" | xml_escape)"
  log="$(printf '%s' "$SUPPORT/login.log" | xml_escape)"
  staged="$(/usr/bin/mktemp "${LOGIN_PLIST}.XXXXXX")"
  /bin/cat > "$staged" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>io.github.qt0713.riseonair.login</string>
<key>RiseOnAirManaged</key><true/>
<key>ProgramArguments</key><array><string>$executable</string><string>--login</string></array>
<key>RunAtLoad</key><true/><key>KeepAlive</key><false/>
<key>StandardOutPath</key><string>$log</string>
<key>StandardErrorPath</key><string>$log</string>
</dict></plist>
PLIST
  /usr/bin/plutil -lint "$staged" >/dev/null
  /bin/chmod 600 "$staged"
  /bin/mv -f "$staged" "$LOGIN_PLIST"
}
remove_login() {
  safe_path "$LOGIN_PLIST"
  if [ -f "$LOGIN_PLIST" ]; then
    /usr/bin/grep -q '<key>RiseOnAirManaged</key>' "$LOGIN_PLIST" || return 1
    /bin/launchctl bootout "gui/$(/usr/bin/id -u)/io.github.qt0713.riseonair.login" 2>/dev/null || true
    /bin/rm -f "$LOGIN_PLIST"
  fi
}
case "$ACTION" in
  register-login) register_login; exit ;;
  remove-login) remove_login; exit ;;
  preflight)
    . "$RESOURCES/engine/scripts/common-macos.sh"
    discover_codex_app
    require_macos_runtime
    "$NODE" "$INJECTOR" --check-payload --theme-dir "$RESOURCES/theme"
    exit ;;
  install)
    # Validate the genuine app/runtime before changing the user's appearance.
    . "$RESOURCES/engine/scripts/common-macos.sh"
    discover_codex_app
    require_macos_runtime
    codex_is_running && fail '请保存输入并退出 Codex / ChatGPT 后，重新打开理世启动器完成首次安装。'
    [ -f "$CONFIG_PATH" ] || fail '请先启动并登录官方客户端一次，再退出后安装理世主题。'
    "$NODE" "$INJECTOR" --check-payload --theme-dir "$RESOURCES/theme" >/dev/null
    /bin/mkdir -p "$SUPPORT"
    /bin/chmod 700 "$SUPPORT"
    lock="$SUPPORT/.install-lock"
    /bin/mkdir "$lock" || fail '另一个理世安装操作正在进行。'
    stage="$(/usr/bin/mktemp -d "$SUPPORT/.engine-stage.XXXXXX")"
    trap '/bin/rmdir "$lock" 2>/dev/null || true' EXIT
    /usr/bin/ditto "$RESOURCES/engine" "$stage/engine"
    safe_path "$ENGINE"
    if [ -e "$ENGINE" ]; then
      [ -f "$ENGINE/RISE-OWNED" ] || fail '现有引擎不属于本项目，拒绝覆盖。'
      previous="$SUPPORT/engine.previous.$(/bin/date +%s).$$"
      /bin/mv "$ENGINE" "$previous"
    fi
    if ! /bin/mv "$stage/engine" "$ENGINE"; then
      [ -z "${previous:-}" ] || /bin/mv "$previous" "$ENGINE"
      fail '部署引擎失败；已尝试恢复原目录。'
    fi
    /bin/rmdir "$stage"
    safe_path "$STATE"
    /bin/mkdir -p "$STATE"
    /bin/chmod 700 "$STATE"
    # Only trusted bundled assets enter this stage; the upstream validator ran above.
    theme_stage="$(/usr/bin/mktemp -d "$STATE/.rise-theme.XXXXXX")"
    "$NODE" "$ENGINE/scripts/stage-theme.mjs" "$RESOURCES/theme" "$theme_stage" >/dev/null
    if [ -e "$STATE/theme" ]; then
      safe_path "$STATE/theme"
      /bin/mv "$STATE/theme" "$STATE/theme.previous.$(/bin/date +%s).$$"
    fi
    /bin/mv "$theme_stage" "$STATE/theme"
    if ! "$ENGINE/scripts/install-dream-skin-macos.sh" --in-place --no-launchers --no-launch; then
      "$ENGINE/scripts/restore-dream-skin-macos.sh" --restore-base-theme || true
      fail '主题初始化失败；请查看日志并重试。'
    fi
    /bin/cp "$RESOURCES/VERSION" "$SUPPORT/installed-version"
    register_login
    printf 'Rise On Air installed.\n' ;;
  launch)
    if [ ! -f "$SUPPORT/installed-version" ] || ! /usr/bin/cmp -s "$RESOURCES/VERSION" "$SUPPORT/installed-version"; then
      "$0" install
    fi
    phase verify-existing
    if "$ENGINE/scripts/verify-dream-skin-macos.sh" > "$SUPPORT/last-verification.json" 2> "$SUPPORT/last-verification-error.log"; then
      register_login
      phase ready-existing
      exit 0
    fi
    phase start-session
    "$ENGINE/scripts/start-dream-skin-macos.sh" --prompt-restart
    phase verify-started
    "$ENGINE/scripts/verify-dream-skin-macos.sh" > "$SUPPORT/last-verification.json"
    register_login
    phase ready-started ;;
  login)
    # Never install, ask for restart or close an existing session at login.
    [ -f "$SUPPORT/installed-version" ] && /usr/bin/cmp -s "$RESOURCES/VERSION" "$SUPPORT/installed-version" || exit 1
    [ -f "$ENGINE/RISE-OWNED" ] || exit 1
    "$ENGINE/scripts/start-dream-skin-macos.sh"
    exec "$ENGINE/scripts/verify-dream-skin-macos.sh" ;;
  restore)
    [ -f "$ENGINE/RISE-OWNED" ] || { printf '未发现本项目已安装的引擎。\n' >&2; exit 1; }
    remove_login
    exec "$ENGINE/scripts/restore-dream-skin-macos.sh" --restore-base-theme --restart-codex ;;
  verify)
    [ -f "$ENGINE/RISE-OWNED" ] || exit 1
    exec "$ENGINE/scripts/verify-dream-skin-macos.sh" ;;
  *) printf 'Unknown action.\n' >&2; exit 2 ;;
esac
