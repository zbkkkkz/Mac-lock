import SwiftUI
import ServiceManagement

struct ControlPanel: View {
    @ObservedObject var state: WorkspaceState
    let quit: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(macOS 26.0, *), !ProcessInfo.processInfo.arguments.contains("--legacy-ui") {
                GlassEffectContainer(spacing: 24) { panelContent }
            } else { panelContent }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: state.isLocked)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: quit) { Label("退出 Mac lock", systemImage: "power") }
                    .help("恢复输入并退出 Mac lock")
            }
        }
    }

    private var panelContent: some View {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    statusIcon
                    VStack(spacing: 6) {
                        Text(state.isLocked ? "输入已锁定" : "随时就绪")
                            .font(.system(size: 27, weight: .semibold))
                        Text(state.isLocked ? "两秒内连按三次 Esc，立即恢复输入" : "每次启动与唤醒，保持解锁")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("锁定范围").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Picker("锁定范围", selection: $state.scope) {
                        Label("仅锁键盘", systemImage: "keyboard").tag(InputScope.keys)
                        Label("键盘与触控板", systemImage: "hand.draw").tag(InputScope.everything)
                    }
                    .pickerStyle(.segmented).controlSize(.large).labelsHidden()
                    .disabled(state.isLocked)
                    Label(state.scope == .keys ? "触控板保持可用，可点击顶部开关解锁" : "全锁无倒计时，连按三次 Esc 解锁", systemImage: state.scope == .keys ? "cursorarrow" : "escape")
                        .font(.caption).foregroundStyle(.secondary)
                }

                primaryAction

                GroupBox {
                    VStack(spacing: 16) {
                        Toggle(isOn: Binding(get: { state.startsAtLogin || state.needsLoginApproval }, set: state.changeLogin)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("登录后启动").font(.system(size: 13, weight: .medium))
                                Text("显示在菜单栏与 Dock，保持解锁")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.switch)
                        if state.needsLoginApproval {
                            Button("允许登录启动…") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        Divider()
                        HStack {
                            Text("系统权限").font(.system(size: 13, weight: .medium))
                            Spacer()
                            permission("辅助功能", allowed: state.hasAccessibility, ax: true)
                            permission("输入监控", allowed: state.hasInputAccess, ax: false)
                            Button { state.syncPermissions() } label: {
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.borderless).help("刷新权限状态")
                        }
                    }.padding(8)
                }
                if let notice = state.notice {
                    Label(notice, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28).frame(width: 500)
    }

    @ViewBuilder private var statusIcon: some View {
        if #available(macOS 26.0, *), !ProcessInfo.processInfo.arguments.contains("--legacy-ui") {
            iconContent.contentTransition(.symbolEffect(.replace))
                .glassEffect(.regular, in: .circle)
        } else {
            iconContent.background(.regularMaterial, in: Circle())
        }
    }

    private var iconContent: some View {
        Image(systemName: state.isLocked ? "lock.fill" : "lock.open")
            .font(.system(size: 30, weight: .medium)).frame(width: 80, height: 80)
    }

    private var actionContent: some View {
        Button { state.switchLock() } label: {
            Label(state.isLocked ? "恢复输入" : "开启锁定", systemImage: state.isLocked ? "lock.open" : "lock")
                .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 32)
        }.controlSize(.large).tint(state.isLocked ? .green : .accentColor)
            .keyboardShortcut(.return, modifiers: [])
    }

    @ViewBuilder private var primaryAction: some View {
        if #available(macOS 26.0, *), !ProcessInfo.processInfo.arguments.contains("--legacy-ui") {
            actionContent.buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            actionContent.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle)
        }
    }

    private func permission(_ title: String, allowed: Bool, ax: Bool) -> some View {
        Button { state.openPrivacy(accessibility: ax) } label: {
            Label(title, systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.caption).foregroundStyle(allowed ? .green : .orange)
        }.buttonStyle(.borderless)
    }
}
