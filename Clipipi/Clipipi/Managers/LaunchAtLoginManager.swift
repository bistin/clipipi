import Foundation
import ServiceManagement

/// 管理「開機時自動啟動」設定。
/// 使用 macOS 13+ 的 `SMAppService.mainApp`，由系統登入項目代管，
/// 使用者也可在「系統設定 → 一般 → 登入項目」中關閉。
@MainActor
final class LaunchAtLoginManager: ObservableObject, Sendable {
    static let shared = LaunchAtLoginManager()

    /// 是否已註冊為登入啟動項目。
    @Published private(set) var isEnabled: Bool
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastError: String?

    private init() {
        isEnabled = (SMAppService.mainApp.status == .enabled)
    }

    /// 依目前系統狀態重新同步（例如使用者在系統設定中手動更改後）。
    func refresh() {
        isEnabled = (SMAppService.mainApp.status == .enabled)
    }

    /// 開啟或關閉開機自動啟動。
    func setEnabled(_ enabled: Bool) {
        statusMessage = nil
        lastError = nil

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            lastError = error.localizedDescription
            NSLog("[Clipipi] 設定開機啟動失敗: \(error.localizedDescription)")
        }

        refresh()

        if lastError == nil {
            statusMessage = isEnabled ? "已開啟開機自動啟動" : "已關閉開機自動啟動"
        }
    }
}
