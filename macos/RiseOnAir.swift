import AppKit
import WebKit

final class RiseApp: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    let args = CommandLine.arguments
    let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/RiseOnAir")
    var window: NSWindow!
    var web: WKWebView!
    var process: Process?
    var introEnded = false
    var ready = false
    var preview = false
    var selfTest = false
    var captured = false
    var audioLoaded = false
    var duration = 0.0
    var messages = [String]()
    var skipped = false
    var output: URL { URL(fileURLWithPath: ProcessInfo.processInfo.environment["RISE_TEST_OUTPUT"] ?? NSTemporaryDirectory()).appendingPathComponent("rise-native-test.json") }
    var resources: URL { Bundle.main.resourceURL! }

    func applicationDidFinishLaunching(_ notification: Notification) {
        selfTest = args.contains("--self-test")
        preview = selfTest || args.contains("--preview")
        if args.contains("--login") {
            NSApp.setActivationPolicy(.accessory)
            runControl("login") { _ in NSApp.terminate(nil) }; return
        }
        setupMenu()
        let installed = try? String(contentsOf: support.appendingPathComponent("installed-version"), encoding: .utf8)
        let version = try? String(contentsOf: resources.appendingPathComponent("VERSION"), encoding: .utf8)
        if !preview && installed == version && installed != nil,
           let codex = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").first {
            // A running native app can be missing the managed CDP session.
            runControl("launch") { success in
                codex.activate(options: [.activateAllWindows])
                if !success {
                    let alert = NSAlert(); alert.messageText = "理世主题尚未通过验证"
                    alert.informativeText = "已保留当前 Codex 会话。请保存输入后退出 Codex，再打开理世启动器；日志位于 Library/Application Support/RiseOnAir。"
                    alert.runModal()
                }
                NSApp.terminate(nil)
            }; return
        }
        if !preview && installed != version {
            let alert = NSAlert()
            alert.messageText = "安装 Rise On Air 理世主题"
            alert.informativeText = "请先保存输入并退出 Codex / ChatGPT。安装只写入你的用户目录，保留官方应用和账户。首次配置需要已安装并运行过官方客户端。"
            alert.addButton(withTitle: "安装并启动")
            alert.addButton(withTitle: "仅预览动画")
            alert.addButton(withTitle: "取消")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { preview = true }
            else if response != .alertFirstButtonReturn { NSApp.terminate(nil); return }
        }
        showWindow()
        if !preview { applyTheme() }
        if selfTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                self?.finishTest(error: "Native player did not finish within 25 seconds")
            }
        }
    }
    func setupMenu() {
        let main = NSMenu(), app = NSMenu(), item = NSMenuItem()
        for (title, action, key) in [("重播预览", #selector(replay), "r"), ("应用 / 重试主题", #selector(retry), ""), ("恢复官方外观", #selector(restore), ""), ("显示日志", #selector(showLogs), "l"), ("退出", #selector(quit), "q")] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key); entry.target = self; app.addItem(entry)
        }
        item.submenu = app; main.addItem(item); NSApp.mainMenu = main
    }
    func showWindow() {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: min(1000, visible.width * 0.86), height: min(650, visible.height * 0.86))
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Codex · Rise On Air"
        window.minSize = NSSize(width: 360, height: 360)
        window.delegate = self; window.center(); window.isReleasedWhenClosed = false
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(self, name: "rise")
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        window.contentView = web
        let folder = resources.appendingPathComponent("animation", isDirectory: true)
        web.loadFileURL(folder.appendingPathComponent("startup-macos.html"), allowingReadAccessTo: folder)
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let allowed = resources.appendingPathComponent("animation").standardizedFileURL.path + "/"
        let url = navigationAction.request.url
        decisionHandler(url?.isFileURL == true && url!.standardizedFileURL.path.hasPrefix(allowed) ? .allow : .cancel)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "rise", let value = message.body as? String, value.count < 1024 else { return }
        messages.append(value)
        if value.hasPrefix("metadata ") { duration = Double(value.dropFirst(9)) ?? 0 }
        if value == "audio-loaded" { audioLoaded = true }
        if value == "ready" { web.evaluateJavaScript("riseHost.start({muted:\(selfTest || args.contains("--muted") ? "true" : "false"),preview:\(preview ? "true" : "false")})", completionHandler: nil) }
        if value == "capture" {
            web.takeSnapshot(with: nil) { [weak self] image, error in
                guard let self = self, let image = image, let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { return }
                if self.selfTest { try? png.write(to: self.output.deletingLastPathComponent().appendingPathComponent("preview.png")) }
                self.captured = true
            }
        }
        if value == "ended" {
            introEnded = true
            if selfTest { finishTest(error: nil) }
            else if !preview { if ready { NSApp.terminate(nil) } else { waiting(false) } }
        }
        if value == "skip" {
            skipped = true
            if preview || ready { NSApp.terminate(nil) } else { window.orderOut(nil) }
        }
        if value.hasPrefix("error ") { if selfTest { finishTest(error: value) } else { waiting(true) } }
    }
    func waiting(_ failed: Bool) { web?.evaluateJavaScript("riseHost.waiting(\(failed ? "true" : "false"))", completionHandler: nil) }
    func runControl(_ action: String, completion: @escaping (Bool) -> Void) {
        guard process == nil else { return }
        do {
            var ancestor = support
            while ancestor.path != "/" {
                let attributes = try? FileManager.default.attributesOfItem(atPath: ancestor.path)
                if attributes?[.type] as? FileAttributeType == .typeSymbolicLink { throw NSError(domain: "Rise", code: 1, userInfo: [NSLocalizedDescriptionKey:"日志路径不能为符号链接。"] ) }
                ancestor.deleteLastPathComponent()
            }
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let log = support.appendingPathComponent("launcher.log")
            if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: log); handle.seekToEndOfFile()
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [resources.appendingPathComponent("rise-control.sh").path, action]
            task.standardOutput = handle; task.standardError = handle; task.standardInput = FileHandle.nullDevice
            task.terminationHandler = { [weak self] child in
                try? handle.close()
                DispatchQueue.main.async { self?.process = nil; completion(child.terminationStatus == 0) }
            }
            process = task; try task.run()
        } catch {
            process = nil
            if !args.contains("--login") {
                let alert = NSAlert(); alert.messageText = "无法执行主题操作"; alert.informativeText = error.localizedDescription; alert.runModal()
            }
            completion(false)
        }
    }
    func applyTheme() {
        runControl("launch") { [weak self] success in
            guard let self = self else { return }; self.ready = success
            if success && (self.introEnded || self.skipped) { NSApp.terminate(nil) }
            else if !success {
                self.waiting(true)
                let alert = NSAlert(); alert.messageText = "主题尚未确认加载"; alert.informativeText = "首次安装请先退出 Codex / ChatGPT，再从菜单重试。已安装时请检查官方客户端版本和日志。"; alert.addButton(withTitle: "显示日志"); alert.addButton(withTitle: "保留预览")
                if alert.runModal() == .alertFirstButtonReturn { self.showLogs() }
            }
        }
    }
    func finishTest(error: String?) {
        guard selfTest else { return }; selfTest = false
        let pass = error == nil && abs(duration - 3.2) < 0.001 && captured && audioLoaded && messages.contains("ended")
        let result: [String: Any] = ["pass":pass,"duration":duration,"captured":captured,"audioLoaded":audioLoaded,"messages":messages,"error":error ?? "","macOS":ProcessInfo.processInfo.operatingSystemVersionString]
        try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys]).write(to: output)
        exit(pass ? 0 : 1)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { if process != nil { skipped = true; sender.orderOut(nil); return false }; NSApp.terminate(nil); return true }
    @objc func replay() { if web != nil { preview = true; web.evaluateJavaScript("riseHost.start({muted:false,preview:true})", completionHandler: nil) } }
    @objc func retry() { preview = false; applyTheme() }
    @objc func showLogs() { NSWorkspace.shared.open(support) }
    @objc func restore() {
        let alert = NSAlert(); alert.messageText = "恢复官方外观"; alert.informativeText = "恢复会退出并重新打开 Codex / ChatGPT，请先保存输入。"; alert.addButton(withTitle: "恢复并重启"); alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn { runControl("restore") { success in if success { NSApp.terminate(nil) } } }
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let application = NSApplication.shared
let delegate = RiseApp()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
