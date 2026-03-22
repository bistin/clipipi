# Clipipi — macOS 剪貼簿歷史管理工具

## 概述

一個 macOS 系統列常駐 App，自動記錄使用者的複製歷史，提供搜尋、快速貼上、釘選等功能。使用 SwiftUI + AppKit 開發，以 NSPanel 懸浮視窗呈現。

## 技術規格

- **語言**: Swift 6+
- **UI**: SwiftUI (macOS 14+ / Sonoma)
- **專案類型**: macOS App (SwiftUI lifecycle)
- **最低部署版本**: macOS 14.0
- **架構**: MVVM
- **不使用任何第三方套件**，全部用系統 API

---

## 待開發功能計畫

### 1. 搜尋強化 ✅
**檔案**: `ClipboardManager.swift`, `MenuBarView.swift`

**目標**:
- 正則表達式搜尋（`/pattern/` 語法）
- 按類型篩選（text, url, code, image）
- 按來源篩選（Slack, Jira, GitHub, etc.）
- 按標籤篩選

**實作**:
1. 在 `ClipboardManager` 加入篩選狀態：
```swift
@Published var filterType: ClipItem.ClipType? = nil
@Published var filterSource: ContentSource? = nil
@Published var filterTag: String? = nil
```

2. 修改 `filteredItems` 支援進階篩選：
```swift
var filteredItems: [ClipItem] {
    var result = items

    // 類型篩選
    if let type = filterType {
        result = result.filter { $0.type == type }
    }

    // 來源篩選
    if let source = filterSource {
        result = result.filter { $0.detectedSource == source }
    }

    // 標籤篩選
    if let tag = filterTag {
        result = result.filter { $0.tags.contains(tag) }
    }

    // 搜尋文字（支援正則）
    if !searchText.isEmpty {
        if searchText.hasPrefix("/") && searchText.hasSuffix("/") && searchText.count > 2 {
            // 正則模式
            let pattern = String(searchText.dropFirst().dropLast())
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = result.filter { item in
                    let range = NSRange(item.content.startIndex..., in: item.content)
                    return regex.firstMatch(in: item.content, range: range) != nil
                }
            }
        } else {
            // 一般搜尋
            result = result.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }
    }

    // 分離釘選
    let pinned = result.filter { $0.isPinned }
    let unpinned = result.filter { !$0.isPinned }
    return pinned + unpinned
}
```

3. 在 `MenuBarView` 加入篩選 UI（搜尋框旁邊的下拉選單或 chip）

---

### 2. 快捷鍵自訂 ✅
**檔案**: `HotkeyManager.swift`, 新增 `SettingsView.swift`

**目標**:
- 讓使用者自訂全域快捷鍵
- 儲存設定到 UserDefaults

**實作**:
1. 建立設定模型：
```swift
struct HotkeySettings: Codable {
    var keyCode: UInt16 = 0x09  // V
    var modifiers: CGEventFlags = [.maskCommand, .maskShift]
}
```

2. 建立設定視窗 `SettingsView.swift`
3. 修改 `HotkeyManager` 讀取自訂設定

---

### 3. 多格式貼上 ✅
**檔案**: `ClipboardManager.swift`, `ClipItemRow.swift`

**目標**:
- 純文字貼上（strip formatting）
- 保留格式貼上
- Markdown 轉換

**實作**:
1. 修改 `pasteItem` 支援格式參數
2. 長按或右鍵顯示格式選單
3. 記住上次選擇

---

### 4. 圖片 OCR ✅
**檔案**: 新增 `OCRManager.swift`, 修改 `ClipItem.swift`

**目標**:
- 使用 Vision framework 辨識圖片文字
- 儲存辨識結果供搜尋

**實作**:
```swift
import Vision

@MainActor
final class OCRManager: Sendable {
    static let shared = OCRManager()

    nonisolated func recognizeText(from image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
```

在 `ClipItem` 加入：
```swift
var ocrText: String?  // OCR 辨識結果
```

在 `ClipboardManager.addImageItem` 中觸發 OCR。

---

### 5. 任務項目拖放排序 ✅

**檔案**: `TaskModeView.swift`

**目標**:
- 任務內項目可拖曳重新排序

**實作**:
使用 SwiftUI `draggable` 和 `dropDestination`：
```swift
ForEach(task.items) { item in
    TaskItemRow(item: item, taskId: task.id)
        .draggable(item.id.uuidString)
}
.dropDestination(for: String.self) { items, location in
    // 重新排序邏輯
}
```

---

### 6. iCloud 同步 ⬜
**檔案**: 新增 `CloudKitManager.swift`, 修改 entitlements

**目標**:
- 跨裝置同步剪貼簿歷史

**注意**: 需要設定 CloudKit container 和 entitlements

---

### 7. 單元測試補充 ✅
**檔案**: `ClipipiTests/`

**目標**:
- 測試搜尋邏輯（正則、篩選）
- 測試 OCR
- 測試任務管理

---

## 開發順序

1. ✅ 搜尋強化
2. ✅ 快捷鍵自訂
3. ✅ 多格式貼上
4. ✅ 圖片 OCR
5. ✅ 拖放排序
6. ~~iCloud 同步~~（不需要）
7. ✅ 單元測試補充

---

## 現有架構

```
Clipipi/
├── ClipipiApp.swift
├── Views/
│   ├── MenuBarView.swift      # 主畫面
│   ├── ClipItemRow.swift      # 列表項目
│   └── TaskModeView.swift     # 任務模式
├── ViewModels/
│   ├── ClipboardManager.swift # 剪貼簿管理
│   └── TaskManager.swift      # 任務管理
├── Models/
│   ├── ClipItem.swift         # 剪貼項目
│   └── Task.swift             # 任務模型
├── Managers/
│   ├── HotkeyManager.swift    # 快捷鍵
│   ├── PanelManager.swift     # 懸浮視窗
│   └── WindowManager.swift    # 視窗管理
└── ClipipiTests/            # 測試
```

---

## 原始規格（已實作）

### Info.plist 設定
- `LSUIElement = YES`（不在 Dock 顯示，僅系統列常駐）

### Sandbox 設定
- **關閉 App Sandbox**（需要存取 NSPasteboard 全域剪貼簿 + CGEvent tap 全域按鍵監聽）

### 已實作功能
- F1: 系統列常駐 ✅
- F2: 剪貼簿監聽 ✅
- F3: 內容類型偵測 ✅
- F4: 主畫面 UI ✅
- F5: 全域快捷鍵 ⌘⇧V ✅
- F6: 懸浮視窗（NSPanel）✅
- F7: 貼上功能 ✅
- F8: 釘選功能 ✅
- F9: 持久化 ✅
- F10: 鍵盤操作 ✅
- 任務模式 ✅
- 圖片支援 ✅
- 標籤功能 ✅
- 權限自動偵測 ✅
