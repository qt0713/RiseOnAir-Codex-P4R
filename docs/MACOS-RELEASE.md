macOS Universal Beta：Apple Silicon / Intel，最低 macOS 14。

- 已有主题先通过上游真实验证，成功时直接复用，不再重复启动注入器。
- 冷热启动统一播放展示动画，主题验证与播放均完成后交接窗口。
- 使用 AppKit 恢复已有应用，修复预览重播和重试时残留的等待状态。
- 增加阶段日志，以及“已有主题有效 / 需要恢复 / 恢复后仍失败”的回归测试。

发布任务依赖 Apple Silicon 和 Intel 两套原生编译、WKWebView 播放、资源安全、签名与 DMG 挂载检查全部通过。

这些 CI 测试不包含已登录的真实 Codex 会话，不代表真实 Mac 的冷启动耗时、关闭主窗口后恢复、重启电脑全部验收。Windows 的私有窗口 IPC 未移植到 Mac。仍采用 ad-hoc 签名，未进行 Apple 公证。

下载 DMG 拖入 Applications，或使用 ZIP；摘要见 SHA256SUMS-macos.txt。已有 beta.2 用户升级前请保存输入并退出官方客户端，再运行新版本完成受管引擎更新。

完整中文说明和素材、上游项目引用见仓库 docs/MACOS.md 与 THIRD_PARTY_NOTICES.md。
