import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @FocusState private var isSearchFocused: Bool
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            headerView

            Divider()

            if showHelp {
                helpView
            } else {
                // 搜尋框
                searchBar

                Divider()

                // 列表
                if clipboardManager.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemListView
                }

                Divider()

                // 底部工具列
                footerView
            }
        }
        .frame(width: 320, height: 480)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.001))
        .onKeyPress(.downArrow) {
            clipboardManager.selectNext()
            return .handled
        }
        .onKeyPress(.upArrow) {
            clipboardManager.selectPrevious()
            return .handled
        }
        .onKeyPress(.return) {
            clipboardManager.pasteSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            if showHelp {
                showHelp = false
                return .handled
            }
            PanelManager.shared.hidePanel()
            return .handled
        }
        .onKeyPress(keys: [.init("f")]) { press in
            if press.modifiers.contains(.command) {
                isSearchFocused = true
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("ClipStash")
                .font(.headline)

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHelp.toggle()
                }
            }) {
                Image(systemName: showHelp ? "xmark.circle.fill" : "questionmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(showHelp ? "關閉說明" : "使用說明")

            Text("\(clipboardManager.itemCount) 筆")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Help View

    private var helpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                helpSection(title: "快捷鍵", items: [
                    ("⌘⇧V", "開啟/關閉視窗"),
                    ("↑ / ↓", "選擇項目"),
                    ("Enter", "貼上選中項目"),
                    ("Esc", "關閉視窗"),
                    ("⌘F", "搜尋")
                ])

                helpSection(title: "操作", items: [
                    ("點擊項目", "貼上該內容"),
                    ("滑鼠懸停", "顯示操作按鈕"),
                    ("📌 釘選", "項目置頂，不會被清除"),
                    ("🗑 清除全部", "刪除所有未釘選項目")
                ])

                helpSection(title: "圖示說明", items: [
                    ("📄", "一般文字"),
                    ("🔗", "網址連結"),
                    ("💻", "程式碼")
                ])

                helpSection(title: "其他", items: [
                    ("自動記錄", "最多保留 100 筆"),
                    ("釘選項目", "不受數量限制"),
                    ("資料儲存", "自動保存，重啟不遺失")
                ])
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func helpSection(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(items, id: \.0) { item in
                HStack(alignment: .top) {
                    Text(item.0)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)

                    Text(item.1)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜尋剪貼簿...", text: $clipboardManager.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !clipboardManager.searchText.isEmpty {
                Button(action: {
                    clipboardManager.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Item List

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 釘選項目
                    if !clipboardManager.pinnedItems.isEmpty {
                        ForEach(clipboardManager.pinnedItems) { item in
                            ClipItemRow(
                                item: item,
                                isSelected: clipboardManager.selectedItemId == item.id,
                                onPaste: { clipboardManager.pasteItem(item) },
                                onTogglePin: { clipboardManager.togglePin(item) },
                                onDelete: { clipboardManager.deleteItem(item) }
                            )
                            .id(item.id)
                        }

                        // 分隔線
                        if !clipboardManager.unpinnedItems.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }

                    // 一般項目
                    ForEach(clipboardManager.unpinnedItems) { item in
                        ClipItemRow(
                            item: item,
                            isSelected: clipboardManager.selectedItemId == item.id,
                            onPaste: { clipboardManager.pasteItem(item) },
                            onTogglePin: { clipboardManager.togglePin(item) },
                            onDelete: { clipboardManager.deleteItem(item) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: clipboardManager.selectedItemId) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            if clipboardManager.searchText.isEmpty {
                Text("尚無剪貼簿歷史")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("找不到符合的結果")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button(action: {
                clipboardManager.clearAll()
            }) {
                Label("清除全部", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(clipboardManager.unpinnedItems.isEmpty)

            Spacer()

            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("結束", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    MenuBarView()
}
