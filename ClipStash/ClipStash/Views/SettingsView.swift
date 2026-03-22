import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt16?
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("設定")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // 快捷鍵設定
            VStack(alignment: .leading, spacing: 12) {
                Text("全域快捷鍵")
                    .font(.headline)

                HStack {
                    Text("開啟 ClipStash：")
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
                        // 至少需要一個修飾鍵
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
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380, height: 280)
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
