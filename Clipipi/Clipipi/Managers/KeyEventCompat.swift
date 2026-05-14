import SwiftUI
import AppKit

/// Key press 資訊，跨 macOS 13/14 統一介面。
struct KeyPressInfo {
    let character: Character
    let modifiers: NSEvent.ModifierFlags

    func matches(_ key: KeyEquivalent) -> Bool {
        character == key.character
    }
}

extension View {
    /// macOS 14+ 走 SwiftUI .onKeyPress；macOS 13 走 NSEvent local monitor。
    /// handler 回傳 true 代表事件已消化、不再往下傳。
    func onKeyDownCompat(handler: @escaping (KeyPressInfo) -> Bool) -> some View {
        modifier(KeyPressCompatModifier(handler: handler))
    }
}

private struct KeyPressCompatModifier: ViewModifier {
    let handler: (KeyPressInfo) -> Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onKeyPress(phases: .down) { press in
                var mods: NSEvent.ModifierFlags = []
                if press.modifiers.contains(.command) { mods.insert(.command) }
                if press.modifiers.contains(.shift) { mods.insert(.shift) }
                if press.modifiers.contains(.option) { mods.insert(.option) }
                if press.modifiers.contains(.control) { mods.insert(.control) }
                let info = KeyPressInfo(character: press.key.character, modifiers: mods)
                return handler(info) ? .handled : .ignored
            }
        } else {
            content.background(KeyEventMonitorRepresentable(handler: handler))
        }
    }
}

private struct KeyEventMonitorRepresentable: NSViewRepresentable {
    let handler: (KeyPressInfo) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyEventMonitorView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyEventMonitorView)?.handler = handler
    }
}

@MainActor
private final class KeyEventMonitorView: NSView {
    var handler: ((KeyPressInfo) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            install()
        } else {
            uninstall()
        }
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let handler = self.handler,
                  self.window?.isKeyWindow == true,
                  let chars = event.charactersIgnoringModifiers,
                  let first = chars.first else { return event }

            let info = KeyPressInfo(
                character: first,
                modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            )
            return handler(info) ? nil : event
        }
    }

    private func uninstall() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
