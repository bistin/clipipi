import SwiftUI
import Carbon
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt16?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("設定")
                    .font(.title2)
                    .fontWeight(.semibold)

                Divider()

                hotkeySection
                generalSection
                exclusionSection
                updateSection

                HStack {
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 420, height: 600)
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全域快捷鍵")
                .font(.headline)

            HStack {
                Text("開啟 Clipipi：")
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    isRecording.toggle()
                    if !isRecording {
                        recordedKeyCode = nil
                        recordedModifiers = []
                    }
                }) {
                    if isRecording {
                        Text("請按下快捷鍵...")
                            .foregroundStyle(Color.accentColor)
                            .frame(minWidth: 140)
                    } else {
                        Text(hotkeyManager.settings.displayString)
                            .frame(minWidth: 140)
                    }
                }
                .buttonStyle(.bordered)
                .onKeyDownCompat { press in
                    guard isRecording else { return false }

                    let modifiers = press.modifiers
                    guard modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) else {
                        return true
                    }

                    let keyCode = keyCodeFromCharacter(press.character)
                    guard keyCode != 0xFFFF else { return true }

                    var cgFlags = CGEventFlags()
                    if modifiers.contains(.command) { cgFlags.insert(.maskCommand) }
                    if modifiers.contains(.shift) { cgFlags.insert(.maskShift) }
                    if modifiers.contains(.option) { cgFlags.insert(.maskAlternate) }
                    if modifiers.contains(.control) { cgFlags.insert(.maskControl) }

                    let newSettings = HotkeySettings(keyCode: keyCode, modifierFlags: cgFlags.rawValue)
                    hotkeyManager.updateSettings(newSettings)
                    isRecording = false
                    return true
                }
            }

            Button("恢復預設 (⌘⇧V)") {
                hotkeyManager.updateSettings(HotkeySettings())
                isRecording = false
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一般")
                .font(.headline)

            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("開機時自動啟動")
                    Text("登入 macOS 後自動在背景啟動 Clipipi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onAppear { launchAtLogin.refresh() }
    }

    // MARK: - Exclusion List

    private var exclusionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("排除的 App")
                    .font(.headline)
                Spacer()
                Button(action: pickAppToExclude) {
                    Label("加入…", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("這些 App 複製的內容不會被記錄。1Password 等機密內容 App 會自動跳過。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if clipboardManager.excludedBundleIds.isEmpty {
                Text("目前沒有排除的 App")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(clipboardManager.excludedBundleIds).sorted(), id: \.self) { bundleId in
                        excludedAppRow(bundleId: bundleId)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func excludedAppRow(bundleId: String) -> some View {
        HStack(spacing: 8) {
            if let icon = AppIconLookup.icon(forBundleId: bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(AppIconLookup.appName(forBundleId: bundleId) ?? bundleId)
                    .font(.system(size: 12))
                if AppIconLookup.appName(forBundleId: bundleId) != nil {
                    Text(bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(action: { clipboardManager.removeExcludedBundleId(bundleId) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
    }

    // MARK: - Update

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("關於與更新")
                .font(.headline)

            HStack {
                Text("目前版本：")
                    .foregroundStyle(.secondary)
                Text("v\(updateChecker.currentVersion)")
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button(action: { updateChecker.check() }) {
                    if case .checking = updateChecker.state {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("檢查中…")
                        }
                    } else {
                        Text("檢查更新")
                    }
                }
                .buttonStyle(.bordered)
                .disabled({ if case .checking = updateChecker.state { return true } else { return false } }())
            }

            updateStatusView
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.state {
        case .idle, .checking:
            EmptyView()
        case .upToDate:
            Label("已是最新版本", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .updateAvailable(let latest, _, _):
            HStack {
                Label("有新版本 v\(latest)", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("前往下載") { updateChecker.openReleasePage() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        case .failed(let message):
            Label("檢查失敗：\(message)", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pickAppToExclude() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "加入排除清單"
        panel.message = "選擇不想記錄剪貼簿的 App"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bid = bundle.bundleIdentifier else { return }

        clipboardManager.addExcludedBundleId(bid)
    }

    /// 從 character 轉換為 CGEvent keyCode
    private func keyCodeFromCharacter(_ char: Character) -> UInt16 {
        let keyMap: [Character: UInt16] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
            "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
            "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
            "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19, "7": 0x1A,
            "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22,
            "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
            "m": 0x2E,
        ]
        return keyMap[char] ?? 0xFFFF
    }
}
