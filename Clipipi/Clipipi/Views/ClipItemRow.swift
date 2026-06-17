import SwiftUI
import AppKit

struct ClipItemRow: View {
    let item: ClipItem
    let index: Int?  // 用於顯示快捷鍵數字 (0-8 對應 ⌘1-9)
    let isSelected: Bool
    let onPaste: () -> Void
    let onPasteWithFormat: ((ClipboardManager.PasteFormat) -> Void)?
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onAddTag: (String) -> Void
    let onRemoveTag: (String) -> Void

    @ObservedObject private var taskManager = TaskManager.shared
    @State private var isHovering = false
    @State private var showTagPopover = false
    @State private var showTaskPopover = false
    @State private var newTagText = ""

    private var relativeTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-Hant")
        formatter.unitsStyle = .full
        return formatter
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 快捷鍵數字 或 類型圖示
            if let idx = index, idx < 9 {
                Text("⌘\(idx + 1)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            } else {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            // 內容
            VStack(alignment: .leading, spacing: 2) {
                if item.type == .image, let nsImage = item.image {
                    // 圖片縮圖
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 60)
                        .cornerRadius(4)

                    // OCR 辨識文字
                    if let ocrText = item.ocrText {
                        Text(ocrText)
                            .font(.system(size: 10))
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                } else {
                    // 文字內容
                    Text(item.content)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }

                // 時間或釘選狀態
                HStack(spacing: 4) {
                    if item.isPinned {
                        Label("釘選", systemImage: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    } else {
                        Text(relativeTimeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    // 來源標籤
                    if item.detectedSource != .unknown {
                        HStack(spacing: 2) {
                            Image(systemName: item.detectedSource.iconName)
                                .font(.system(size: 9))
                            Text(item.detectedSource.rawValue)
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                    }

                    // 收集標記
                    if let taskId = item.taskId,
                       let task = taskManager.tasks.first(where: { $0.id == taskId }) {
                        HStack(spacing: 2) {
                            Image(systemName: "tray.full.fill")
                                .font(.system(size: 9))
                            Text(task.name)
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(3)
                    }

                    // 來源 App
                    if let appName = item.sourceAppName {
                        HStack(spacing: 3) {
                            if let bid = item.sourceBundleId,
                               let icon = AppIconLookup.icon(forBundleId: bid) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 11, height: 11)
                            }
                            Text(appName)
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                    }

                    // 顯示標籤
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()

            // Hover 時顯示操作按鈕
            if isHovering {
                HStack(spacing: 4) {
                    // 貼上
                    Button(action: onPaste) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("貼上")

                    // 加入/移出收集
                    Button(action: {
                        handleCollectionAction()
                    }) {
                        Image(systemName: collectionActionIcon)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(collectionActionColor)
                    .help(collectionActionHelp)
                    .popover(isPresented: $showTaskPopover, arrowEdge: .bottom) {
                        taskPopoverContent
                    }

                    // 標籤
                    Button(action: { showTagPopover.toggle() }) {
                        Image(systemName: "tag")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("標籤")
                    .popover(isPresented: $showTagPopover, arrowEdge: .bottom) {
                        tagPopoverContent
                    }

                    // 釘選/取消釘選
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "取消釘選" : "釘選")

                    // 刪除
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("刪除")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onPaste()
        }
        .contextMenu {
            // 右鍵選單：多格式貼上
            if item.type != .image {
                Button(action: { onPasteWithFormat?(.original) ?? onPaste() }) {
                    Label("貼上原始格式", systemImage: "doc.richtext")
                }
                Button(action: { onPasteWithFormat?(.plainText) ?? onPaste() }) {
                    Label("貼上純文字", systemImage: "doc.text")
                }
                Button(action: { onPasteWithFormat?(.markdown) ?? onPaste() }) {
                    Label("貼上 Markdown", systemImage: "text.document")
                }
                Button(action: { onPasteWithFormat?(.trimmed) ?? onPaste() }) {
                    Label("貼上（去頭尾空白）", systemImage: "scissors")
                }
                Divider()
            }

            Button(action: onTogglePin) {
                Label(item.isPinned ? "取消釘選" : "釘選", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    private var isInActiveCollection: Bool {
        guard let taskId = item.taskId,
              let activeId = taskManager.activeTaskId else { return false }
        return taskId == activeId
    }

    private var collectionActionIcon: String {
        if isInActiveCollection {
            return "tray.full.fill"
        }
        if item.taskId != nil {
            return "tray.and.arrow.down.fill"
        }
        return "plus.square.on.square"
    }

    private var collectionActionColor: Color {
        if isInActiveCollection { return Color.accentColor }
        if taskManager.activeTask != nil { return .green }
        return .secondary
    }

    private var collectionActionHelp: String {
        if isInActiveCollection {
            return "移出收集"
        }
        if let task = taskManager.activeTask {
            return "加入「\(task.name)」"
        }
        if !taskManager.activeTasks.isEmpty {
            return "加入收集"
        }
        return "建立收集"
    }

    private func handleCollectionAction() {
        if isInActiveCollection {
            taskManager.removeClipItemFromCollection(item)
            return
        }
        if let task = taskManager.activeTask {
            taskManager.addItemToTask(item, task: task)
            return
        }
        if !taskManager.activeTasks.isEmpty {
            showTaskPopover.toggle()
            return
        }
        WindowManager.shared.openTaskModeWindow()
        PanelManager.shared.hidePanel()
    }

    // MARK: - Tag Popover

    private var tagPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("標籤")
                .font(.headline)

            // 新增標籤
            HStack {
                TextField("新增標籤...", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        addNewTag()
                    }

                Button(action: addNewTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newTagText.isEmpty)
            }

            // 現有標籤
            if !item.tags.isEmpty {
                Divider()
                ForEach(item.tags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                            .font(.system(size: 12))
                        Spacer()
                        Button(action: { onRemoveTag(tag) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 180)
    }

    private func addNewTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        onAddTag(tag)
        newTagText = ""
    }

    // MARK: - Task Popover

    private var taskPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("加入收集")
                .font(.headline)

            ForEach(taskManager.activeTasks) { task in
                Button(action: {
                    taskManager.addItemToTask(item, task: task)
                    taskManager.setActiveTask(task)
                    showTaskPopover = false
                }) {
                    HStack {
                        Image(systemName: task.status.iconName)
                            .foregroundStyle(task.status == .active ? .green : .orange)
                        Text(task.name)
                            .font(.system(size: 12))
                        Spacer()
                        if taskManager.isItemInTask(item, task: task) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(width: 180)
    }
}

#Preview {
    VStack(spacing: 0) {
        ClipItemRow(
            item: ClipItem(content: "https://github.com/example/repo"),
            index: 0,
            isSelected: false,
            onPaste: {},
            onPasteWithFormat: nil,
            onTogglePin: {},
            onDelete: {},
            onAddTag: { _ in },
            onRemoveTag: { _ in }
        )
        ClipItemRow(
            item: ClipItem(content: "SELECT * FROM users WHERE id = 1;"),
            index: 1,
            isSelected: true,
            onPaste: {},
            onPasteWithFormat: nil,
            onTogglePin: {},
            onDelete: {},
            onAddTag: { _ in },
            onRemoveTag: { _ in }
        )
        ClipItemRow(
            item: ClipItem(content: "這是一段普通的文字內容，用於測試顯示效果。", isPinned: true, tags: ["工作", "重要"]),
            index: nil,
            isSelected: false,
            onPaste: {},
            onPasteWithFormat: nil,
            onTogglePin: {},
            onDelete: {},
            onAddTag: { _ in },
            onRemoveTag: { _ in }
        )
    }
    .frame(width: 320)
    .padding()
}
