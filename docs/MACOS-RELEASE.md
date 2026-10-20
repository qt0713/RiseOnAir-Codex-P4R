macOS Universal Beta：Apple Silicon / Intel，最低 macOS 14。

- beta.4：启动改为首帧验证，检查正确主题与 payload 版本、活动样式、本地壁纸解码与实际绘制、可见主页面和基础控件结构。完整布局审计移到后台，失败单独记录，不撤销已经显示的主题。
- 已有会话探测预算缩短为 1.5 秒，避免主题未加载时先等完整的 30 秒检查再开始注入；正常恢复仍由上游的真实身份校验与事务完成。
- 冷热启动统一播放展示动画，首帧验证与播放均完成后交接窗口。
- 使用 AppKit 恢复已有应用，修复预览重播和重试时残留的等待状态。
- 增加阶段日志，以及“已有主题有效 / 需要恢复 / 恢复后仍失败”的回归测试。

发布任务依赖 Apple Silicon 和 Intel 两套原生编译、WKWebView 播放、资源安全、签名与 DMG 挂载检查全部通过。

这些 CI 测试不包含已登录的真实 Codex 会话，不代表真实 Mac 的冷启动耗时、关闭主窗口后恢复、重启电脑全部验收。Windows 的私有窗口 IPC 未移植到 Mac。仍采用 ad-hoc 签名，未进行 Apple 公证。

下载 DMG 拖入 Applications，或使用 ZIP；摘要见 SHA256SUMS-macos.txt。已有 beta.3 用户升级前请保存输入并退出官方客户端，再运行新版本完成受管引擎更新。

完整中文说明和素材、上游项目引用见仓库 docs/MACOS.md 与 THIRD_PARTY_NOTICES.md。
