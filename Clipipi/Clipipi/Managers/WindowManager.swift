import Foundation
import AppKit
import SwiftUI

@MainActor
final class WindowManager: ObservableObject, Sendable {
    static let shared = WindowManager()

    private var taskModeWindow: NSWindow?
    private var settingsWindow: NSWindow?

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

    // MARK: - Settings Window

    func openSettingsWindow() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: SettingsView())
        window.title = "Clipipi 設定"
        window.minSize = NSSize(width: 400, height: 520)
        window.center()
        window.setFrameAutosaveName("ClipipiSettingsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = SettingsWindowDelegate.shared

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func settingsWindowDidClose() {
        settingsWindow = nil
    }
}

// MARK: - Window Delegates

@MainActor
final class TaskModeWindowDelegate: NSObject, NSWindowDelegate, Sendable {
    static let shared = TaskModeWindowDelegate()

    nonisolated func windowWillClose(_ notification: Notification) {
        // 視窗關閉時的處理（可選）
    }
}

@MainActor
final class SettingsWindowDelegate: NSObject, NSWindowDelegate, Sendable {
    static let shared = SettingsWindowDelegate()

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            WindowManager.shared.settingsWindowDidClose()
        }
    }
}