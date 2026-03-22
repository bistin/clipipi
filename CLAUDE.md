# Clipipi

macOS 剪貼簿歷史管理工具，系統列常駐 App。

## 技術架構

- **語言**: Swift 6
- **UI**: SwiftUI (macOS 14+)
- **架構**: MVVM
- **無第三方套件**

## 專案結構

```
Clipipi/
├── ClipipiApp.swift           # App 入口 + MenuBarExtra
├── Views/
│   ├── MenuBarView.swift        # 主畫面 UI（標題、搜尋、列表、工具列、說明）
│   └── ClipItemRow.swift        # 列表項目元件
├── ViewModels/
│   └── ClipboardManager.swift   # 剪貼簿監聽、資料管理、持久化
├── Models/
│   └── ClipItem.swift           # 資料模型（id, content, timestamp, type, isPinned）
├── Managers/
│   ├── HotkeyManager.swift      # 全域快捷鍵 ⌘⇧V（CGEvent tap）
│   └── PanelManager.swift       # NSPanel 懸浮視窗管理
├── Assets.xcassets/
├── Info.plist                   # LSUIElement = YES
└── Clipipi.entitlements       # App Sandbox 關閉
```

## 核心功能

| 功能 | 實作方式 |
|------|----------|
| 系統列常駐 | `MenuBarExtra` + `.menuBarExtraStyle(.window)` |
| 剪貼簿監聽 | `Timer` 每 0.5 秒輪詢 `NSPasteboard.general.changeCount` |
| 全域快捷鍵 | `CGEvent.tapCreate` 攔截 ⌘⇧V（需要輔助使用權限）|
| 懸浮視窗 | 自訂 `KeyablePanel: NSPanel` + `NSVisualEffectView` 毛玻璃 |
| 持久化 | `UserDefaults` JSON 編碼，key: `clip_stash_items` |
| 內容類型偵測 | URL（http/https）、程式碼（關鍵字偵測）、文字 |

## 重要注意事項

### Swift 6 Concurrency
- `ClipboardManager`, `HotkeyManager`, `PanelManager` 都標記 `@MainActor` + `Sendable`
- `kAXTrustedCheckOptionPrompt` 需用硬編碼字串 `"AXTrustedCheckOptionPrompt"` 避免 concurrency 錯誤

### 權限
- **輔助使用權限**：全域快捷鍵和模擬按鍵必須
- 從 Xcode 重新 Build 後需要重新授權（簽章改變）

### NSPanel
- 需要 override `canBecomeKey` 回傳 `true` 才能接收鍵盤焦點
- 使用 `orderFrontRegardless()` + `makeKey()` 顯示

## Build 指令

```bash
cd Clipipi
xcodebuild -scheme Clipipi -configuration Release archive -archivePath ./build/Clipipi.xcarchive
cp -R ./build/Clipipi.xcarchive/Products/Applications/Clipipi.app /Applications/
```

## 快捷鍵

| 按鍵 | 功能 |
|------|------|
| ⌘⇧V | 開啟/關閉懸浮視窗 |
| ↑/↓ | 選擇項目 |
| Enter | 貼上選中項目 |
| Esc | 關閉視窗 |
| ⌘F | 聚焦搜尋框 |
