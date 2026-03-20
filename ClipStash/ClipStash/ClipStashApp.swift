import SwiftUI

@main
struct ClipStashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "clipboard")
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化 ClipboardManager（開始監聽剪貼簿）
        _ = ClipboardManager.shared

        // 初始化 PanelManager
        PanelManager.shared.setupPanel()

        // 啟動全域快捷鍵
        HotkeyManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
    }
}
