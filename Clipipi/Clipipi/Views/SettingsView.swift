import SwiftUI
import Carbon
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared
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
                exclusionSection

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
        .frame(width: 420, height: 520)
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
                .onKeyPress(phases: .down) { press in
                    guard isRecording else { return .ignored }

                    let modifiers = press.modifiers
                    guard modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) else {
                        return .handled
                    }

                    let keyCode = keyCodeFromKeyEquivalent(press.key)
                    guard keyCode != 0xFFFF else { return .handled }

                    var cgFlags = CGEventFlags()
                    if modifiers.contains(.command) { cgFlags.insert(.maskCommand) }
                    if modifiers.contains(.shift) { cgFlags.insert(.maskShift) }
                    if modifiers.contains(.option) { cgFlags.insert(.maskAlternate) }
                    if modifiers.contains(.control) { cgFlags.insert(.maskControl) }

                    let newSettings = HotkeySettings(keyCode: keyCode, modifierFlags: cgFlags.rawValue)
                    hotkeyManager.updateSettings(newSettings)
                    isRecording = false
                    return .handled
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

    /// 從 KeyEquivalent 轉換為 CGEvent keyCode
    private func keyCodeFromKeyEquivalent(_ key: KeyEquivalent) -> UInt16 {
        let char = key.character
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
