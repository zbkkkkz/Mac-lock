import AppKit
import SwiftUI
import Combine
import ServiceManagement
@preconcurrency import ApplicationServices

@MainActor
final class WorkspaceState: ObservableObject {
    @Published var scope: InputScope = .keys
    @Published private(set) var isLocked = false
    @Published private(set) var hasAccessibility = false
    @Published private(set) var hasInputAccess = false
    @Published private(set) var startsAtLogin = false
    @Published private(set) var needsLoginApproval = false
    @Published var notice: String?
    private let gate = InputGate()
    init() {
        gate.didStop = { [weak self] unexpected in
            self?.isLocked = false
            self?.notice = unexpected ? "系统暂停了输入拦截，已自动解除锁定。" : nil
        }
        syncPermissions()
    }
    func syncPermissions() {
        hasAccessibility = AXIsProcessTrusted()
        hasInputAccess = CGPreflightListenEventAccess()
        startsAtLogin = SMAppService.mainApp.status == .enabled
        needsLoginApproval = SMAppService.mainApp.status == .requiresApproval
    }
    func switchLock() {
        if isLocked { release(); return }
        syncPermissions()
        guard hasAccessibility && hasInputAccess else {
            notice = "请在系统设置中为「Mac lock」开启辅助功能和输入监控。"
            return
        }
        do { try gate.engage(scope); isLocked = gate.running; notice = nil }
        catch { isLocked = false; notice = "系统未允许锁定，请检查权限并重新打开Mac lock。" }
    }
    func release() { gate.disengage(); isLocked = false; notice = nil }
    func changeLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else { try SMAppService.mainApp.unregister() }
            UserDefaults.standard.set(true, forKey: "macLockLoginConfigured")
        } catch { notice = "登录启动设置未完成，请在系统设置 → 通用 → 登录项中检查。" }
        syncPermissions()
    }
    func initializeLogin() {
        if !UserDefaults.standard.bool(forKey: "macLockLoginConfigured") { changeLogin(true) }
    }
    func openPrivacy(accessibility: Bool) {
        let section = accessibility ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(section)")!)
    }
}

@main
struct PersonalLockApplication: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var controller
    @StateObject private var state = WorkspaceState()
    var body: some Scene {
        WindowGroup("Mac lock") {
            ControlPanel(state: state, quit: { controller.quitApplication() })
                .onAppear { controller.install(state) }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in state.release() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in state.release(); state.syncPermissions() }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in state.release() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in state.syncPermissions() }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) { Button("显示Mac lock") { controller.reveal() } }
            CommandGroup(replacing: .appTermination) { Button("退出Mac lock") { controller.quitApplication() }.keyboardShortcut("q") }
            CommandGroup(replacing: .newItem) { }
        }
    }
}

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        state?.release()
        return .terminateNow
    }

    private weak var state: WorkspaceState?
    private var item: NSStatusItem?
    private var panel: NSWindow?
    private var subscription: AnyCancellable?
    func install(_ state: WorkspaceState) {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) { panel = window; window.delegate = self }
        guard item == nil else { return }
        self.state = state
        let status = NSStatusBar.system.statusItem(withLength: 38)
        item = status
        status.button?.target = self
        status.button?.action = #selector(activateSwitch)
        status.button?.sendAction(on: .leftMouseUp)
        subscription = state.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.paintSwitch() } }
        paintSwitch()
        state.initializeLogin()
        let event = NSAppleEventManager.shared().currentAppleEvent
        let login = ProcessInfo.processInfo.arguments.contains("--login") || event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if login { panel?.orderOut(nil) }
    }
    private func paintSwitch() {
        let enabled = state?.isLocked == true
        let image = NSImage(size: NSSize(width: 30, height: 18), flipped: false) { frame in
            let track = NSBezierPath(roundedRect: frame.insetBy(dx: 0, dy: 1), xRadius: 8, yRadius: 8)
            (enabled ? NSColor.systemGreen : NSColor(calibratedWhite: 0.5, alpha: 1)).setFill()
            track.fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: enabled ? 15 : 1, y: 2, width: 14, height: 14)).fill()
            return true
        }
        image.isTemplate = false
        item?.button?.image = image
        item?.button?.toolTip = enabled ? "Mac lock：已开启 · 连按三次 Esc 恢复" : "Mac lock：已关闭 · 点击开启\(state?.scope.rawValue ?? "")"
        item?.button?.setAccessibilityLabel(enabled ? "锁定已开启，点击关闭" : "锁定已关闭，点击开启")
    }
    @objc private func activateSwitch() {
        state?.switchLock()
        if state?.notice != nil { reveal() }
    }
    func reveal() { panel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func quitApplication() { state?.release(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { state?.release() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { reveal(); return true }
}
