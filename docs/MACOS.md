# macOS 下载与使用

macOS 当前版为 **1.1.0-beta.2**，提供 Universal 原生应用（Apple Silicon / Intel），最低 macOS 14。

## 安装

1. 先安装并运行官方 Codex / 新版 ChatGPT 桌面客户端一次，再退出。主题引擎要求官方包 ID `com.openai.codex`，并校验其应用签名、OpenAI Team ID 和自带 Node 运行时；缺少合格运行时会停止，不会要求安装 Homebrew 或来历不明的 Node。
2. 下载 `RiseOnAir-v1.1.0-beta.2-macos-universal.dmg`，打开后把 **Rise On Air.app** 拖入 Applications。也提供 ZIP 作为替代。
3. 打开 Rise On Air，按原生提示安装并启动。首次配置或引擎升级前请保存输入并退出官方客户端；后续客户端已经运行时，仍会验证并应用主题，再唤起窗口。

## 登录恢复与 Dock 入口

安装后创建当前用户登录项 `~/Library/LaunchAgents/io.github.qt0713.riseonair.login.plist`。下一次登录时，原生启动器以 `--login` 静默建立主题会话，同时打开 Codex；不播放动画、不弹 Terminal、不自动重启已有客户端。若官方客户端抢先以普通模式启动，后台操作记录失败并保留工作，需保存后退出官方客户端、从 Rise On Air 重新启动。

请在 macOS 的系统登录项中关闭官方 Codex / ChatGPT 的重复自动打开，仅保留理世登录恢复。普通官方入口与主题入口同时自启动会产生竞争；本项目不会自动关闭已经打开的工作。

Dock 日常冷启动请固定 **Rise On Air.app**。登录恢复成功后，点击官方 Codex 的 Dock 图标会唤起已有主题会话；本项目不修改官方 Dock 应用包，也不能给任意普通启动补加 CDP 参数。关闭登录项、手动完全退出后直接冷启动官方图标，仍属于普通入口。系统禁止后台项目时需按系统设置自行允许。

“恢复官方外观”会移除本项目登录项。登录项指向安装位置，移动应用后请从新位置打开一次完成注册；不要从挂载中的 DMG 安装主题。

本项目没有 Apple Developer ID 和公证资格，构建使用 ad-hoc 完整性签名。Gatekeeper 可能阻止首次打开：请由你自行按照系统的“隐私与安全性”提示处理。不要关闭 Gatekeeper，不需要执行删除隔离属性的命令。

## 功能

- 原生 AppKit 窗口与 WKWebView 本地播放，3.2 秒展示动画及理世日语招呼；静音按钮、M、Esc 跳过，菜单支持重播预览。
- 原生窗口可缩放，Retina 分辨率支持；动画根据内容区域选择宽屏、紧凑和竖屏布局。
- 理世 ICNS 图标；可以将应用保留在 Dock。不会替换官方客户端图标或修改官方应用包。
- 同时启动主题接入与动画。动画结束后尚未验证主题时显示安静等待；只有上游真实验证成功才结束等待。不会把动画时长当作加载进度。
- 保留 Windows 版已经补齐的思考/工具摘要半透明、明黄主按钮与深色箭头兼容样式。

## 数据、恢复与卸载

本项目引擎、主题状态和日志均位于：

`~/Library/Application Support/RiseOnAir/`

它与普通 Dream Skin 的共享安装目录隔离；不覆盖其他主题引擎。引擎源自上游 v1.5.21，构建时核对精确源码摘要，再修改本项目自己的状态目录、launchd 标识和理世 CSS 加载入口。官方 `.app`、签名与账户文件保持原样。主题仍通过本机回环 CDP 运行，CDP 无同用户身份验证，使用边界见上游安全说明。

恢复时在应用菜单选择 **恢复官方外观**，确认保存输入后执行恢复并重启官方客户端。恢复成功后可以把 Rise On Air.app 移到废纸篓。默认保留用户目录内的恢复副本与日志；不要在恢复前删除这些文件。

## 测试范围

GitHub Actions 在 `macos-15`（Apple Silicon）和 `macos-15-intel` 上编译 Universal 二进制并运行原生 WKWebView 自测，检查本地动画播放、字体/图片、音频元数据、截图、资源摘要、缺少官方应用时拒绝安装、配置保留、符号链接拒绝和 DMG 挂载。每次测试报告与原生预览图作为 Actions Artifact 保存。

**这些测试不等于登录用户真实 Codex 主题接入通过。** CI 不包含你的账号、聊天或登录状态；尚需在真实 Mac 的当前官方客户端上完成主题加载、恢复和日常冷启动验收。因此本版标记为 Beta，无法确认支持的客户端会停止并提供日志，不将模拟界面当成主题加载成功。

角色、录音、字体、上游引擎的来源和许可见根目录 `THIRD_PARTY_NOTICES.md`。这不是 OpenAI、ATLUS 或 SEGA 官方产品。

## beta.1 的历史测试结果

[macOS 原生构建与测试 run 39155338626](https://github.com/qt0713/RiseOnAir-Codex-P4R/actions/runs/39155338626) 已通过。Apple Silicon 与 Intel 均在 macOS 15.7.9 上运行：原生 WKWebView 播放 3.2 秒并结束、音频元数据与播放启动正常、截图成功，资源与配置保护检查通过；Universal 双架构检查、ad-hoc 签名校验和 DMG 只读挂载验证通过。

![Mac runner 原生窗口播放截图](macos-native-preview.png)

构建来源为提交 `b1c2264be04f5c8bfdd311e3eb340c31df2bd518`；后续提交只补充测试记录与文档。下载包来自通过测试的 Apple Silicon runner，同一 Universal 二进制同时包含 arm64 与 x86_64。Intel runner 另行构建并运行了原生测试。
