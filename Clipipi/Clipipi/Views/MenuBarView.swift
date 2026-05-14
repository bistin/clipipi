import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var taskManager = TaskManager.shared
    @FocusState private var isSearchFocused: Bool
    @State private var showHelp = false
    @State private var showFilters = false
    @State private var showSettings = false

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

                // 篩選列
                if showFilters || clipboardManager.hasActiveFilters {
                    filterBar
                }

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
        .onKeyDownCompat { press in
            if press.matches(.downArrow) {
                clipboardManager.selectNext()
                return true
            }
            if press.matches(.upArrow) {
                clipboardManager.selectPrevious()
                return true
            }
            if press.matches(.return) {
                clipboardManager.pasteSelected()
                return true
            }
            if press.matches(.escape) {
                if showHelp {
                    showHelp = false
                } else {
                    PanelManager.shared.hidePanel()
                }
                return true
            }
            if press.modifiers.contains(.command) {
                if press.character == "f" {
                    isSearchFocused = true
                    return true
                }
                if let num = press.character.wholeNumberValue, num >= 1, num <= 9 {
                    clipboardManager.pasteItemAtIndex(num - 1)
                    return true
                }
            }
            return false
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Clipipi")
                .font(.headline)

            Spacer()

            // 任務模式按鈕
            Button(action: {
                WindowManager.shared.openTaskModeWindow()
                PanelManager.shared.hidePanel()
            }) {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundStyle(taskManager.activeTasks.isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("任務模式")

            // 當前任務指示器
            if let activeTask = taskManager.activeTask {
                Text(activeTask.name)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }

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
                    ("⌘1~9", "快速貼上前 9 筆"),
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

                helpSection(title: "搜尋篩選", items: [
                    ("/pattern/", "正則表達式搜尋"),
                    ("篩選按鈕", "按類型、來源、標籤篩選"),
                ])

                helpSection(title: "其他", items: [
                    ("自動記錄", "最多保留 100 筆"),
                    ("釘選項目", "不受數量限制"),
                    ("資料儲存", "自動保存，重啟不遺失")
                ])

                helpSection(title: "權限設定", items: [
                    ("輔助使用", "系統設定 → 隱私與安全性 → 輔助使用"),
                    ("自動偵測", "授權後約 2 秒內自動生效")
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

            TextField("搜尋（/regex/ 正則）", text: $clipboardManager.searchText)
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

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showFilters.toggle()
                }
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle\(showFilters || clipboardManager.hasActiveFilters ? ".fill" : "")")
                    .font(.system(size: 14))
                    .foregroundStyle(clipboardManager.hasActiveFilters ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("篩選")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 6) {
            // 類型篩選
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("類型")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    ForEach([ClipItem.ClipType.text, .url, .code, .image], id: \.self) { type in
                        filterChip(
                            label: type.displayName,
                            icon: type.iconName,
                            isSelected: clipboardManager.filterType == type
                        ) {
                            clipboardManager.filterType = clipboardManager.filterType == type ? nil : type
                        }
                    }

                    Divider()
                        .frame(height: 16)

                    Text("來源")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    ForEach(ContentSource.allCases.filter { $0 != .unknown }, id: \.self) { source in
                        filterChip(
                            label: source.rawValue,
                            icon: source.iconName,
                            isSelected: clipboardManager.filterSource == source
                        ) {
                            clipboardManager.filterSource = clipboardManager.filterSource == source ? nil : source
                        }
                    }
                }
            }

            // 標籤篩選（僅在有標籤時顯示）
            if !clipboardManager.allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("標籤")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        ForEach(clipboardManager.allTags, id: \.self) { tag in
                            filterChip(
                                label: tag,
                                icon: "tag",
                                isSelected: clipboardManager.filterTag == tag
                            ) {
                                clipboardManager.filterTag = clipboardManager.filterTag == tag ? nil : tag
                            }
                        }
                    }
                }
            }

            // 清除篩選
            if clipboardManager.hasActiveFilters {
                HStack {
                    Spacer()
                    Button(action: {
                        clipboardManager.clearFilters()
                    }) {
                        Text("清除篩選")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func filterChip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(label)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
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
                                index: clipboardManager.indexOfItem(item),
                                isSelected: clipboardManager.selectedItemId == item.id,
                                onPaste: { clipboardManager.pasteItem(item) },
                                onPasteWithFormat: { format in clipboardManager.pasteItem(item, format: format) },
                                onTogglePin: { clipboardManager.togglePin(item) },
                                onDelete: { clipboardManager.deleteItem(item) },
                                onAddTag: { tag in clipboardManager.addTag(tag, to: item) },
                                onRemoveTag: { tag in clipboardManager.removeTag(tag, from: item) }
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
                            index: clipboardManager.indexOfItem(item),
                            isSelected: clipboardManager.selectedItemId == item.id,
                            onPaste: { clipboardManager.pasteItem(item) },
                            onPasteWithFormat: { format in clipboardManager.pasteItem(item, format: format) },
                            onTogglePin: { clipboardManager.togglePin(item) },
                            onDelete: { clipboardManager.deleteItem(item) },
                            onAddTag: { tag in clipboardManager.addTag(tag, to: item) },
                            onRemoveTag: { tag in clipboardManager.removeTag(tag, from: item) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: clipboardManager.selectedItemId) { newId in
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
                showSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("設定")
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }

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
