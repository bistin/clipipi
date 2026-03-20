# ClipStash — macOS 剪貼簿歷史管理工具

## 概述

一個 macOS 系統列常駐 App，自動記錄使用者的複製歷史，提供搜尋、快速貼上、釘選等功能。使用 SwiftUI + AppKit 開發，以 NSPanel 懸浮視窗呈現。

## 技術規格

- **語言**: Swift 6+
- **UI**: SwiftUI (macOS 14+ / Sonoma)
- **專案類型**: macOS App (SwiftUI lifecycle)
- **最低部署版本**: macOS 14.0
- **架構**: MVVM
- **不使用任何第三方套件**，全部用系統 API

## Info.plist 設定

- `LSUIElement = YES`（不在 Dock 顯示，僅系統列常駐）

## Sandbox 設定

- **關閉 App Sandbox**（需要存取 NSPasteboard 全域剪貼簿 + CGEvent tap 全域按鍵監聽）

## 功能需求

### F1: 系統列常駐

- 使用 `MenuBarExtra` 在系統列顯示圖示（SF Symbol: `clipboard`）
- 點擊圖示展開主視窗（`.menuBarExtraStyle(.window)`）
- App 啟動後不顯示任何主視窗，僅出現在系統列

### F2: 剪貼簿監聽

- 使用 `Timer` 每 0.5 秒輪詢 `NSPasteboard.general.changeCount`
- 偵測到變化時讀取 `NSPasteboard.general.string(forType: .string)`
- 忽略空白內容與重複內容（與最新一筆比對）
- 若已存在相同內容，移除舊的並插入到列表頂部（去重 + 提升）
- 最多保留 **100 筆**

### F3: 內容類型偵測

每筆記錄自動偵測類型，用於顯示不同圖示：

| 類型 | 偵測邏輯 | SF Symbol |
|------|---------|-----------|
| URL | 能被 `URL(string:)` 解析且 scheme 為 http/https | `link` |
| 程式碼 | 包含常見關鍵字：`func `, `def `, `fn `, `const `, `import `, `SELECT `, `=>`, `\|>`, `kubectl `, `docker `, `git ` 等 | `chevron.left.forwardslash.chevron.right` |
| 文字 | 以上都不符合 | `doc.text` |

### F4: 主畫面 UI

從系統列圖示展開的視窗，固定寬度 **320pt**，最大高度 **480pt**：

```
┌──────────────────────────────┐
│  ClipStash          42 筆    │  ← 標題列
├──────────────────────────────┤
│  🔍 搜尋剪貼簿...            │  ← 搜尋框
├──────────────────────────────┤
│  📄 SELECT * FROM users...   │  ← 項目列表（ScrollView + LazyVStack）
│     3 分鐘前                 │
│  🔗 https://github.com/...   │
│     15 分鐘前                │
│  📄 一段普通文字內容...       │
│     1 小時前                 │
│  📌 我的常用 SSH 指令...      │  ← 釘選項目（置頂）
│     釘選                     │
├──────────────────────────────┤
│  🗑 清除全部     ⌘⇧V 快速開啟│  ← 底部工具列
└──────────────────────────────┘
```

**列表項目互動：**
- 單擊：將該項目內容寫入系統剪貼簿，並模擬 ⌘V 貼上
- Hover：右側顯示操作按鈕（貼上、釘選/取消釘選、刪除）
- 釘選項目始終置頂，與一般項目之間用分隔線區隔

**搜尋：**
- 即時篩選，`localizedCaseInsensitiveContains`
- 搜尋框右側有清除按鈕（`xmark.circle.fill`）
- 無結果時顯示空狀態提示

**時間顯示：**
- 使用 `RelativeDateTimeFormatter`，locale 設為 `zh-Hant`

### F5: 全域快捷鍵 ⌘⇧V

- 使用 `CGEvent.tapCreate` 攔截全域鍵盤事件
- 偵測 ⌘+Shift+V（keyCode `0x09`，flags 含 `.maskCommand` 和 `.maskShift`）
- 觸發時 toggle 懸浮視窗（NSPanel）的顯示/隱藏
- 攔截到該快捷鍵後吃掉事件（return nil），不傳遞給其他 App
- 第一次使用需要輔助使用權限（`AXIsProcessTrustedWithOptions`），自動彈窗提示

### F6: 懸浮視窗（NSPanel）

由 ⌘⇧V 觸發的獨立懸浮視窗，與 MenuBarExtra 的內容相同但作為獨立浮動面板：

**NSPanel 設定：**
- `styleMask`: `.nonactivatingPanel`, `.fullSizeContentView`, `.borderless`
- `level`: `.floating`
- `isFloatingPanel`: true
- `hidesOnDeactivate`: true（點擊其他地方自動收起）
- `isMovableByWindowBackground`: true
- `collectionBehavior`: `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- `backgroundColor`: `.clear`
- `hasShadow`: true

**外觀：**
- 使用 `NSVisualEffectView` 毛玻璃背景
- `material`: `.hudWindow`
- `blendingMode`: `.behindWindow`
- 圓角 12pt
- 位置：螢幕正中偏上（類似 Spotlight）

**內容：**
- 使用 `NSHostingView` 嵌入與 MenuBarView 相同的 SwiftUI View

### F7: 貼上功能

- 將選中項目的文字寫入 `NSPasteboard.general`
- 更新 `lastChangeCount` 避免被自己的監聽器重複捕捉
- 模擬鍵盤 ⌘V：用 `CGEvent` 發送 keyDown/keyUp（virtualKey `0x09`, flags `.maskCommand`）
- 貼上後將該項目移到列表頂部
- 自動收起懸浮視窗

### F8: 釘選功能

- 每個項目可被釘選/取消釘選
- 釘選項目永遠顯示在列表最上方，與一般項目用 `Divider` 分隔
- 釘選項目不受「清除全部」影響
- 釘選項目不受 100 筆上限影響
- 釘選狀態持久化

### F9: 持久化

- 使用 `UserDefaults` 儲存（key: `clip_stash_items`）
- 資料格式：JSON encode `[ClipItem]`
- 每次資料變動時自動存檔（新增、刪除、釘選、移動順序）
- App 啟動時自動載入

### F10: 鍵盤操作（Nice to have）

在懸浮視窗顯示時支援鍵盤操作：

- `↑` / `↓`：在列表項目間移動焦點
- `Enter`：貼上當前選中項目
- `Esc`：關閉懸浮視窗
- `⌘F`：聚焦搜尋框
- 輸入任意文字：自動聚焦搜尋框並開始篩選

## 資料模型

```swift
struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipType       // .text | .url | .code
    var isPinned: Bool       // 釘選狀態

    enum ClipType: String, Codable {
        case text, url, code
    }
}
```

## 檔案結構

```
ClipStash/
├── ClipStashApp.swift         // @main App 入口，MenuBarExtra 設定
├── Views/
│   ├── MenuBarView.swift      // 主畫面（標題列 + 搜尋 + 列表 + 工具列）
│   └── ClipItemRow.swift      // 單一項目 Row component
├── ViewModels/
│   └── ClipboardManager.swift // 剪貼簿監聽、資料管理、持久化（ObservableObject）
├── Models/
│   └── ClipItem.swift         // 資料模型
├── Managers/
│   ├── HotkeyManager.swift    // 全域快捷鍵 ⌘⇧V
│   └── PanelManager.swift     // NSPanel 懸浮視窗生命週期管理
└── Info.plist
```

## 注意事項

1. **權限**：App 需要輔助使用權限才能使用全域快捷鍵和模擬按鍵。第一次執行會自動彈窗請求，使用者授權後可能需要重啟 App。
2. **Sandbox**：必須關閉 App Sandbox，否則 NSPasteboard 和 CGEvent tap 無法正常運作。
3. **主線程**：所有 UI 更新和 `@Published` 屬性修改必須在主線程執行（`DispatchQueue.main.async`）。
4. **Timer 記憶體管理**：`Timer` 需要在 `deinit` 中 `invalidate()`，且 closure 中使用 `[weak self]` 避免 retain cycle。
5. **CGEvent tap 存活**：`CFMachPort` 需要被持有（存為 property），否則會被 ARC 釋放導致快捷鍵失效。