import Foundation
import AppKit
import Carbon

@MainActor
final class HotkeyManager: Sendable {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func start() {
        print("ClipStash: HotkeyManager.start() called")

        // 檢查輔助使用權限
        let trusted = checkAccessibilityPermission()
        print("ClipStash: Accessibility permission = \(trusted)")

        if !trusted {
            print("ClipStash: 需要輔助使用權限，請在系統設定中授權後重啟 App")
            return
        }

        setupEventTap()
    }

    nonisolated private func checkAccessibilityPermission() -> Bool {
        // "AXTrustedCheckOptionPrompt" 是 kAXTrustedCheckOptionPrompt 的實際字串值
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func stop() {
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
            print("ClipStash: 無法建立事件監聽器")
            return
        }

        eventTap = tap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("ClipStash: 全域快捷鍵已啟用")
    }

    nonisolated private static func handleEventStatic(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 如果 tap 被系統停用，重新啟用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 檢查 ⌘⇧V (keyCode 0x09 = V, 需要 Command + Shift)
        let isCommandPressed = flags.contains(.maskCommand)
        let isShiftPressed = flags.contains(.maskShift)
        let isVKey = keyCode == 0x09

        if isVKey && isCommandPressed && isShiftPressed {
            // 確保沒有其他修飾鍵（如 Option, Control）
            let unwantedFlags: CGEventFlags = [.maskAlternate, .maskControl]
            let hasUnwantedFlags = !flags.intersection(unwantedFlags).isEmpty

            if !hasUnwantedFlags {
                DispatchQueue.main.async {
                    PanelManager.shared.togglePanel()
                }
                // 吃掉事件，不傳遞給其他 App
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }
}
