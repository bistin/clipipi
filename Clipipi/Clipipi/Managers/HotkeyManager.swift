import Foundation
import AppKit
import Carbon

/// 快捷鍵設定
struct HotkeySettings: Codable, Equatable {
    var keyCode: UInt16 = 0x09  // V
    var modifierFlags: UInt64 = CGEventFlags([.maskCommand, .maskShift]).rawValue

    var cgModifiers: CGEventFlags {
        CGEventFlags(rawValue: modifierFlags)
    }

    /// 顯示用字串，如 "⌘⇧V"
    var displayString: String {
        var parts: [String] = []
        let flags = cgModifiers
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x19: "9", 0x1A: "7",
            0x1C: "8", 0x1D: "0", 0x1F: "O", 0x20: "U", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N",
            0x2E: "M",
        ]
        return keyMap[code] ?? "?"
    }
}

@MainActor
final class HotkeyManager: ObservableObject, Sendable {
    static let shared = HotkeyManager()

    @Published private(set) var settings: HotkeySettings
    @Published private(set) var hasAccessibilityPermission: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionCheckTimer: Timer?
    private var lastPermissionState: Bool = false

    private static let settingsKey = "clip_stash_hotkey_settings"

    /// 全域可存取的當前設定（供 static callback 使用）
    nonisolated(unsafe) private static var currentKeyCode: UInt16 = 0x09
    nonisolated(unsafe) private static var currentModifiers: UInt64 = CGEventFlags([.maskCommand, .maskShift]).rawValue

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(HotkeySettings.self, from: data) {
            self.settings = saved
        } else {
            self.settings = HotkeySettings()
        }
        Self.currentKeyCode = settings.keyCode
        Self.currentModifiers = settings.modifierFlags
    }

    func updateSettings(_ newSettings: HotkeySettings) {
        settings = newSettings
        Self.currentKeyCode = newSettings.keyCode
        Self.currentModifiers = newSettings.modifierFlags

        if let encoded = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
        }

        // 重新設定 event tap 以套用新快捷鍵
        if lastPermissionState {
            stopEventTap()
            setupEventTap()
        }
    }

    func start() {
        let trusted = checkAccessibilityPermission(showPrompt: false)
        hasAccessibilityPermission = trusted
        lastPermissionState = trusted

        if trusted {
            setupEventTap()
        }

        startPermissionCheck()
    }

    /// 開啟系統設定的「輔助使用」頁面，並觸發系統授權提示
    func requestAccessibilityPermission() {
        openAccessibilitySettings()

        // 系統對話框（部分 macOS 版本會額外跳出「開啟系統設定」提示）
        let trusted = checkAccessibilityPermission(showPrompt: true)
        applyPermissionState(trusted)
    }

    /// 直接開啟系統設定的「輔助使用」頁面
    @discardableResult
    func openAccessibilitySettings() -> Bool {
        // 選單列 App 需先取得焦點，否則 open URL 可能沒反應
        NSApp.activate(ignoringOtherApps: true)

        let candidates = [
            // macOS 13+ System Settings
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            // 舊版 System Preferences
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            // 退而求其次：隱私與安全性主頁
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
        ]

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }

        // 最後手段：用 open 指令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [candidates[0]]
        try? process.run()
        return true
    }

    private func applyPermissionState(_ trusted: Bool) {
        hasAccessibilityPermission = trusted

        if trusted && !lastPermissionState {
            setupEventTap()
        } else if !trusted && lastPermissionState {
            stopEventTap()
        }

        lastPermissionState = trusted
    }

    /// 靜默刷新權限狀態（不跳出系統對話框）
    func refreshAccessibilityStatus() {
        recheckPermission()
    }

    nonisolated private func checkAccessibilityPermission(showPrompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": showPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func startPermissionCheck() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recheckPermission()
            }
        }
    }

    private func recheckPermission() {
        let currentState = checkAccessibilityPermission(showPrompt: false)
        applyPermissionState(currentState)
    }

    func stop() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        stopEventTap()
    }

    private func stopEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return HotkeyManager.handleEventStatic(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    nonisolated private static func handleEventStatic(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 從全域設定讀取目標快捷鍵
        let targetKeyCode = currentKeyCode
        let targetModifiers = CGEventFlags(rawValue: currentModifiers)

        guard keyCode == Int64(targetKeyCode) else {
            return Unmanaged.passRetained(event)
        }

        // 檢查所需的修飾鍵
        let requiredFlags: [CGEventFlags] = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        for flag in requiredFlags {
            let required = targetModifiers.contains(flag)
            let pressed = flags.contains(flag)
            if required != pressed {
                return Unmanaged.passRetained(event)
            }
        }

        DispatchQueue.main.async {
            PanelManager.shared.togglePanel()
        }
        return nil
    }
}
