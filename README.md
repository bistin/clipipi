# Clipipi

macOS 剪貼簿歷史管理工具，系統列常駐 App。

## 功能

- **剪貼簿歷史** — 自動記錄複製內容，最多 100 筆
- **全域快捷鍵** — ⌘⇧V 開啟懸浮視窗（可自訂）
- **搜尋** — 支援正則表達式 (`/pattern/`)、按類型 / 來源 / 標籤篩選
- **多格式貼上** — 右鍵選擇原始格式、純文字、Markdown
- **圖片支援** — 圖片剪貼 + OCR 文字辨識（中 / 英）
- **釘選** — 重要內容置頂，不受數量限制
- **標籤** — 自訂標籤分類管理
- **任務模式** — 收集剪貼簿內容到任務，支援 Slack / Jira / GitHub 來源偵測
- **Widget** — 桌面小工具快速存取

## 截圖

> TODO

## 系統需求

- macOS 14.0 (Sonoma) 以上
- 輔助使用權限（全域快捷鍵 + 模擬貼上）

## 安裝

### 從原始碼 Build

```bash
cd Clipipi
xcodebuild -scheme Clipipi -configuration Release archive -archivePath ./build/Clipipi.xcarchive
cp -R ./build/Clipipi.xcarchive/Products/Applications/Clipipi.app /Applications/
```

## 快捷鍵

| 按鍵 | 功能 |
|------|------|
| ⌘⇧V | 開啟 / 關閉懸浮視窗 |
| ⌘1~9 | 快速貼上前 9 筆 |
| ↑ / ↓ | 選擇項目 |
| Enter | 貼上選中項目 |
| Esc | 關閉視窗 |
| ⌘F | 搜尋 |

## 技術

- Swift 6 / SwiftUI
- macOS 14+, MVVM
- 無第三方套件
- Vision framework (OCR)
- CGEvent tap (全域快捷鍵)
- NSPanel (懸浮視窗)

## 授權

MIT
