import Cocoa
import SwiftUI

/// 面板数据源
final class PanelModel: ObservableObject {
    private let core = HelperCore.shared

    @Published private(set) var apps: [AppEntry] = []
    @Published private(set) var isBusy = false
    @Published private(set) var statusText = "在列表中选择一个正在运行的 App，为它开启系统游戏模式"
    @Published private(set) var detailText = ""
    @Published var selectedBundleID: String = "" {
        didSet { updateSelectionInfo() }
    }
    @Published private(set) var selectedState: AppEntry.SupportState = .unknown

    /// 上一次自动跟随前台选中的 bundleID。
    /// 用户手动点选后清空——此后刷新不再自动改选，直到用户重新打开面板。
    @Published private(set) var lastAutoSelected = ""

    /// 用户通过文件面板选择的 App（可能是未安装目录里的）
    @Published var customApp: AppEntry?

    init() {
        refresh()
    }

    var selectedApp: AppEntry? {
        if let custom = customApp { return custom }
        return apps.first { $0.bundleID == selectedBundleID }
    }

    func refresh() {
        core.scanRunningAppsAsync { [weak self] list in
            DispatchQueue.main.async {
                guard let self else { return }
                self.apps = list
                // 自动跟随前台：仅当用户从未选择、或当前仍是上一次自动选中的 App。
                // 用户手动选过的不覆盖。
                if self.selectedBundleID.isEmpty || self.selectedBundleID == self.lastAutoSelected {
                    if let front = list.first(where: { $0.isFrontmost }) {
                        self.selectedBundleID = front.bundleID
                        self.lastAutoSelected = front.bundleID
                    } else if self.selectedBundleID.isEmpty, let first = list.first {
                        self.selectedBundleID = first.bundleID
                        self.lastAutoSelected = first.bundleID
                    }
                }
                // 选中的 App 已经退出运行：若是自动跟随的，交给上面的前台跟随逻辑；
                // 若是手动选的则保持（操作区会显示默认提示）
                self.updateSelectionInfo()
            }
        }
    }

    /// 用户在列表里手动点了某个 App（此后刷新不再自动跟随前台）
    func userPicked(_ id: String?) {
        lastAutoSelected = ""
        customApp = nil
        selectedBundleID = id ?? ""
    }

    private func updateSelectionInfo() {
        guard let app = selectedApp else {
            selectedState = .unknown
            statusText = "在列表中选择一个正在运行的 App，为它开启系统游戏模式"
            detailText = ""
            return
        }
        selectedState = app.supportState
        if app.isSystemVolume {
            statusText = "「\(app.name)」是系统自带 App（只读系统卷）"
            detailText = "它受 SIP 保护、位于只读系统卷上，无法修改声明，因此不能通过本工具开启游戏模式。"
            return
        }
        switch app.supportState {
        case .unsupported:
            statusText = "「\(app.name)」还没有游戏模式声明\(app.isFrontmost ? "（前台）" : "")"
            detailText = "开启并重启后，它以原生全屏（⌃⌘F）运行时，macOS 会自动开启游戏模式：CPU/GPU 优先调度、后台任务降载、蓝牙键鼠手柄采样率翻倍。可随时一键还原。"
        case .supported:
            statusText = "「\(app.name)」已具备游戏模式资格"
            detailText = "重启后，它以原生全屏运行时 macOS 会自动开启游戏模式；不需要时可随时「还原默认」。按 ⌘Esc 可呼出系统的 Game Overlay 查看模式状态。"
        case .unknown:
            statusText = "「\(app.name)」状态未知"
            detailText = ""
        }
    }

    // MARK: - 操作

    func enableSelected() {
        guard let app = selectedApp else { return }
        isBusy = true
        core.enableGameMode(path: app.path) { [weak self] outcome in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch outcome {
                case .success(let msg):
                    self.statusText = "✅ \(msg)"
                    self.detailText = "重启「\(app.name)」后生效：它以原生全屏（⌃⌘F）运行时，macOS 会自动开启游戏模式。"
                case .needsAdmin:
                    self.statusText = "❌ 需要管理员权限（意外路径）"
                case .failed(let msg):
                    self.statusText = "❌ \(msg)"
                }
                self.refresh()
            }
        }
    }

    func disableSelected() {
        guard let app = selectedApp else { return }
        isBusy = true
        core.disableGameMode(path: app.path) { [weak self] outcome in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch outcome {
                case .success(let msg):
                    self.statusText = "✅ \(msg)"
                    self.detailText = "已恢复「\(app.name)」的原始 Info.plist，重启后完全回到从前。"
                case .needsAdmin:
                    self.statusText = "❌ 需要管理员权限（意外路径）"
                case .failed(let msg):
                    self.statusText = "❌ \(msg)"
                }
                self.refresh()
            }
        }
    }

    /// 重启 App（用户明确点击 + 确认后才走到这里）
    func restartSelected() {
        guard let app = selectedApp else { return }
        let alert = NSAlert()
        alert.messageText = "重启「\(app.name)」？"
        alert.informativeText = "改动需要重启该 App 才能生效。\n它会正常退出并重新打开（未保存的内容可能丢失）。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "重启")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertSecondButtonReturn { return }

        isBusy = true
        core.restartApp(path: app.path) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                self.statusText = ok ? "✅「\(app.name)」已重启，声明已生效" : "❌ 重启未完成（App 没有正常退出，已放弃启动以避免双开）"
                if ok { self.detailText = "现在把它切到原生全屏（⌃⌘F）试试；按 ⌘Esc 可呼出 Game Overlay 查看游戏模式状态。" }
                self.refresh()
            }
        }
    }

    /// 通过文件面板选择 App
    func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let name = url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
            customApp = AppEntry(bundleID: core.bundleIDOfAppPublic(path: path) ?? path,
                                 name: name, path: path,
                                 isRunning: core.isAppRunning(bundleID: core.bundleIDOfAppPublic(path: path) ?? ""),
                                 supportState: core.supportStatePublic(path: path))
            lastAutoSelected = ""
            selectedBundleID = customApp?.bundleID ?? ""
            updateSelectionInfo()
        }
    }

    /// 面板「管理员授权」按钮：预先授权，本会话内后续操作全部免密
    func preAuthorize() {
        isBusy = true
        core.preAuthorize { [weak self] err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                let alert = NSAlert()
                if let err {
                    alert.messageText = "授权未完成"
                    alert.informativeText = err
                    alert.alertStyle = .warning
                } else {
                    alert.messageText = "✅ 管理员授权成功"
                    alert.informativeText = "本次运行期间，开启 / 还原 / 重启都不再需要输入密码。"
                    alert.alertStyle = .informational
                }
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
        }
    }

    func runSelfTest() {
        DispatchQueue.global(qos: .userInitiated).async {
            let results = self.core.runSelfTest()
            var text = ""
            var fails = 0
            for c in results {
                switch c.status {
                case .pass: text += "✅ \(c.name)：\(c.detail)\n"
                case .fail: text += "❌ \(c.name)：\(c.detail)\n"; fails += 1
                case .info: text += "ℹ️ \(c.name)：\(c.detail)\n"
                }
            }
            text += fails == 0 ? "\n全部通过。" : "\n有 \(fails) 项未通过。"
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "自检结果"
                alert.informativeText = text
                alert.alertStyle = fails == 0 ? .informational : .warning
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
        }
    }
}
