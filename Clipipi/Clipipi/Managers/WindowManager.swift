import Foundation
import AppKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject, Sendable {
    static let shared = WindowManager()

    private var taskModeWindow: NSWindow?

    private init() {}

    // MARK: - Task Mode Window

    func openTaskModeWindow() {
        if let existingWindow = taskModeWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = TaskModeView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Clipipi - 任務模式"
        window.center()
        window.setFrameAutosaveName("TaskModeWindow")
        window.isReleasedWhenClosed = false

        // 視窗關閉時清除引用
        window.delegate = TaskModeWindowDelegate.shared

        taskModeWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeTaskModeWindow() {
        taskModeWindow?.close()
        taskModeWindow = nil
    }

    func isTaskModeWindowOpen() -> Bool {
        taskModeWindow?.isVisible ?? false
    }
}

// MARK: - Window Delegate

@MainActor
final class TaskModeWindowDelegate: NSObject, NSWindowDelegate, Sendable {
    static let shared = TaskModeWindowDelegate()

    nonisolated func windowWillClose(_ notification: Notification) {
        // 視窗關閉時的處理（可選）
    }
}
