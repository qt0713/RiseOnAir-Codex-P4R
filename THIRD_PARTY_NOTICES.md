# 第三方项目与素材说明

本项目是个人同人主题，不是 ATLUS、SEGA 或 OpenAI 官方产品。源代码的 MIT 许可不覆盖第三方人物、录音、字体或运行库。

| 项目或素材 | 来源、用途与许可边界 |
| --- | --- |
| Codex Dream Skin | [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)，固定使用 [v1.5.21](https://github.com/Fei-Away/Codex-Dream-Skin/releases/tag/v1.5.21)，MIT。负责真实客户端的主题加载、原生控件兼容、主题包校验和恢复。本项目不是该项目的官方发行版。完整许可见 `licenses/Codex-Dream-Skin-MIT.txt`。 |
| 久慈川理世与 Persona 系列 | 角色及游戏相关权利归 ATLUS / SEGA 等相应权利方所有。本项目采用 Persona 4 的电视包装意象制作原创同人构图，不声明是经确认的官方 P4R 立绘。 |
| 造型参考 | 项目发起者提供的、带 DAT 签名的参考插画。原作者主页和原图发布地址未核实；仓库不分发该参考原图，也不把 DAT 签名解释为官方来源。 |
| 人物透明图、主题壁纸、快捷方式图标 | 使用内置 imagegen 根据上述参考生成。发型、棕色双马尾、粉色耳饰与黄边制服以参考图为依据。生成素材不是游戏原始资源，亦不意味着获得角色商业授权。 |
| 日语招呼 | 「やっほー！りせちーだよ～」，久慈川理世原始宣传录音，CV：钉宫理惠。[ATLUS 官方发布页](https://p-ch.jp/news/634/)、[官方 P4D × DENON 视频](https://www.youtube.com/watch?v=RcDYtORu-Nw)、[商品及台词页](https://store.kadokawa.co.jp/shop/g/g3000130600049/)。取原片 1.28–3.58 秒，约 2.30 秒；动画 0.68 秒起播，仅做增益与短淡化，没有克隆声线或添加完整原声。这是 **P4D 宣传录音**，不是 P4R/P4G 游戏内采样。录音权利不纳入本项目 MIT 许可。 |
| Barlow Condensed | [google/fonts/ofl/barlowcondensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed)，SIL Open Font License 1.1，用于动画英文排版。见 `licenses/BarlowCondensed-OFL.txt`。 |
| Noto Sans SC | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)，SIL Open Font License 1.1。发布包使用字重 500 的本地子集，派生字体重命名为 Rise Sans SC Subset。见 `licenses/NotoSansSC-OFL.txt`。不分发从 Windows 提取的微软雅黑或 Arial Narrow。 |
| Microsoft WebView2 | [Microsoft 官方文档](https://learn.microsoft.com/microsoft-edge/webview2/)、[SDK 1.0.4258.31](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.4258.31)。发布包包含所需 SDK 运行文件与原许可/NOTICE；系统缺少 Runtime 时调用微软官方安装引导程序。 |
| Node.js | Dream Skin 官方安装器携带其受验证的 Node.js 22.23.1 运行时；随上游保留 Node 许可。本项目不替换其签名与校验机制。 |
| Inno Setup | [jrsoftware/issrc](https://github.com/jrsoftware/issrc)，本版用 6.5.3 编译。中文消息文件来自上游 Windows 安装器，其许可见 `licenses/Inno-Setup-License.txt`。 |
| HyperFrames | 制作过程中参考 [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes) 的创意、时间轴和音轨工作流；发布动画使用本地 Web Animations API，不包含 GSAP 或 HyperFrames 执行文件。 |

如需转载、商业使用或重新分发人物与录音，请分别核对相应权利来源；署名和链接不改变这些素材的权利归属。关于来源或署名的更正可通过仓库 Issue 提交。

本项目 v1.0.1 对用户目录内 Dream Skin v1.5.21 的 injector.mjs 加入一个按主题 ID 加载本地 CSS 的适配入口。原 MIT 许可保持；修改源码与可逆安装脚本见 installer/Surface-Patch.ps1，样式见 src/runtime/rise-surfaces.css。该修改不属于上游官方发行版。
