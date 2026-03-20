import Foundation
import AppKit
import SwiftUI

// 自訂 Panel 允許成為 key window
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PanelManager: NSObject, Sendable {
    static let shared = PanelManager()

    private var panel: KeyablePanel?
    private var visualEffectView: NSVisualEffectView?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private override init() {
        super.init()
    }

    func setupPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false  // 改為 false，手動控制隱藏
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.becomesKeyOnlyIfNeeded = false  // 允許成為 key

        // 毛玻璃背景
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        // SwiftUI 內容
        let hostingView = NSHostingView(rootView: MenuBarView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor)
        ])

        panel.contentView = visualEffect
        self.visualEffectView = visualEffect
        self.panel = panel

        // 監聽視窗失去焦點
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    @objc private func windowDidResignKey() {
        hidePanel()
    }

    func showPanel() {
        guard let panel = panel else {
            setupPanel()
            showPanel()
            return
        }

        // 計算位置：螢幕正中偏上
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 320
            let panelHeight: CGFloat = 480

            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.midY + screenFrame.height * 0.1 // 偏上一點

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        print("ClipStash: showPanel - displaying at \(panel.frame)")
        panel.orderFrontRegardless()
        panel.makeKey()

        // 確保視窗在最前面
        NSApp.activate(ignoringOtherApps: true)

        // 重置選擇和搜尋
        ClipboardManager.shared.searchText = ""
        ClipboardManager.shared.selectedItemId = nil
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }

    func togglePanel() {
        print("ClipStash: togglePanel called, isVisible = \(isVisible)")
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
}
