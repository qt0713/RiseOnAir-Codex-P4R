#!/bin/bash
set -euo pipefail
RESOURCES="$(cd "$(dirname "$0")" && pwd -P)"
SUPPORT="$HOME/Library/Application Support/RiseOnAir"
ENGINE="$SUPPORT/engine"
STATE="$SUPPORT/DreamSkin"
ACTION="${1:-launch}"
safe_path() {
  local p="$1"
  while [ "$p" != / ] && [ -n "$p" ]; do
    [ ! -L "$p" ] || { printf '拒绝写入符号链接路径：%s\n' "$p" >&2; exit 1; }
    p="$(/usr/bin/dirname "$p")"
  done
}
safe_path "$SUPPORT"
case "$ACTION" in
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
    printf 'Rise On Air installed.\n' ;;
  launch)
    if [ ! -f "$SUPPORT/installed-version" ] || ! /usr/bin/cmp -s "$RESOURCES/VERSION" "$SUPPORT/installed-version"; then
      "$0" install
    fi
    "$ENGINE/scripts/start-dream-skin-macos.sh" --prompt-restart
    "$ENGINE/scripts/verify-dream-skin-macos.sh" > "$SUPPORT/last-verification.json"
    printf 'Rise theme verified.\n' ;;
  restore)
    [ -f "$ENGINE/RISE-OWNED" ] || { printf '未发现本项目已安装的引擎。\n' >&2; exit 1; }
    exec "$ENGINE/scripts/restore-dream-skin-macos.sh" --restore-base-theme --restart-codex ;;
  verify)
    [ -f "$ENGINE/RISE-OWNED" ] || exit 1
    exec "$ENGINE/scripts/verify-dream-skin-macos.sh" ;;
  *) printf 'Unknown action.\n' >&2; exit 2 ;;
esac
