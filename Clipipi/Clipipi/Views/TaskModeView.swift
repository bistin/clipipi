import SwiftUI

struct TaskModeView: View {
    @ObservedObject var taskManager = TaskManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @State private var selectedTask: ClipTask?
    @State private var showCreateTask = false
    @State private var newTaskName = ""
    @State private var newTaskChannel = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarView
        } detail: {
            if let task = selectedTask ?? taskManager.activeTask {
                TaskDetailView(taskId: task.id)
            } else {
                emptyStateView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 500)
        .sheet(isPresented: $showCreateTask) {
            createTaskSheet
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        columnVisibility = columnVisibility == .all ? .detailOnly : .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("顯示/隱藏側邊欄")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $selectedTask) {
            // 建立新任務按鈕
            Section {
                Button(action: { showCreateTask = true }) {
                    Label("建立新任務", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            // 進行中的任務
            if !taskManager.activeTasks.isEmpty {
                Section("進行中 (\(taskManager.activeTasks.count))") {
                    ForEach(taskManager.activeTasks) { task in
                        TaskSidebarRow(task: task, isActive: taskManager.activeTaskId == task.id)
                            .tag(task)
                            .contextMenu {
                                taskContextMenu(for: task)
                            }
                    }
                }
            }

            // 已完成的任務
            if !taskManager.completedTasks.isEmpty {
                Section("已完成 (\(taskManager.completedTasks.count))") {
                    ForEach(taskManager.completedTasks.prefix(10)) { task in
                        TaskSidebarRow(task: task, isActive: false)
                            .tag(task)
                            .contextMenu {
                                taskContextMenu(for: task)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("沒有進行中的任務")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("建立新任務開始收集剪貼簿內容")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button(action: { showCreateTask = true }) {
                Label("建立任務", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create Task Sheet

    private var createTaskSheet: some View {
        VStack(spacing: 20) {
            Text("建立新任務")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("任務名稱")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("例如：修復登入問題", text: $newTaskName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Slack Channel（選填）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("例如：#ops-requests 或 Channel ID", text: $newTaskChannel)
                    .textFieldStyle(.roundedBorder)
                Text("也可以稍後從 Slack URL 自動解析")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button("取消") {
                    resetCreateTaskForm()
                    showCreateTask = false
                }
                .buttonStyle(.bordered)

                Button("建立") {
                    createTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskName.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 400)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func taskContextMenu(for task: ClipTask) -> some View {
        Button {
            taskManager.setActiveTask(task)
        } label: {
            Label("設為作用中", systemImage: "star.fill")
        }
        .disabled(task.status == .completed)

        Divider()

        if task.status == .active {
            Button {
                taskManager.pauseTask(task)
            } label: {
                Label("暫停", systemImage: "pause")
            }
        } else if task.status == .paused {
            Button {
                taskManager.resumeTask(task)
            } label: {
                Label("繼續", systemImage: "play")
            }
        }

        if task.status != .completed {
            Button {
                taskManager.completeTask(task)
            } label: {
                Label("完成", systemImage: "checkmark.circle")
            }
        }

        Divider()

        Button {
            taskManager.copyMarkdownToClipboard(task)
        } label: {
            Label("複製 Markdown", systemImage: "doc.on.doc")
        }

        Button {
            taskManager.exportTaskToFile(task)
        } label: {
            Label("匯出檔案", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            taskManager.deleteTask(task)
            if selectedTask?.id == task.id {
                selectedTask = nil
            }
        } label: {
            Label("刪除", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func createTask() {
        if let task = taskManager.createTask(name: newTaskName, slackChannel: newTaskChannel) {
            selectedTask = task
        }
        resetCreateTaskForm()
        showCreateTask = false
    }

    private func resetCreateTaskForm() {
        newTaskName = ""
        newTaskChannel = ""
    }
}

// MARK: - Task Sidebar Row

struct TaskSidebarRow: View {
    let task: ClipTask
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            // 狀態圖示
            Image(systemName: task.status.iconName)
                .foregroundStyle(statusColor)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.name)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    if isActive {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 4) {
                    Text("\(task.items.count) 筆")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    if !task.slackChannel.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(task.slackChannel)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch task.status {
        case .active: return .green
        case .paused: return .orange
        case .completed: return .gray
        }
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let taskId: UUID
    @ObservedObject var taskManager = TaskManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @State private var editingName = false
    @State private var editedName = ""
    @State private var editingChannel = false
    @State private var editedChannel = ""

    // 從 TaskManager 取得最新的任務資料
    private var task: ClipTask? {
        taskManager.tasks.first { $0.id == taskId }
    }

    var body: some View {
        if let task = task {
            VStack(spacing: 0) {
                // Header
                taskHeader(task)

                Divider()

                // Content
                if task.items.isEmpty {
                    emptyItemsView
                } else {
                    taskItemsList(task)
                }

                Divider()

                // Footer
                taskFooter(task)
            }
        } else {
            // 任務已被刪除
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("任務已刪除")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private func taskHeader(_ task: ClipTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 任務名稱
                if editingName {
                    TextField("任務名稱", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            taskManager.updateTaskName(task, name: editedName)
                            editingName = false
                        }
                } else {
                    Text(task.name)
                        .font(.title2.bold())
                        .onTapGesture(count: 2) {
                            editedName = task.name
                            editingName = true
                        }
                }

                Spacer()

                // 狀態 Badge
                statusBadge(task)
            }

            HStack(spacing: 16) {
                // Slack Channel
                HStack(spacing: 4) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    if editingChannel {
                        TextField("Channel", text: $editedChannel)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .onSubmit {
                                taskManager.updateSlackChannel(task, channel: editedChannel)
                                editingChannel = false
                            }
                    } else {
                        Text(task.slackChannel.isEmpty ? "點擊設定 Channel" : task.slackChannel)
                            .foregroundStyle(task.slackChannel.isEmpty ? .tertiary : .secondary)
                            .onTapGesture {
                                editedChannel = task.slackChannel
                                editingChannel = true
                            }
                    }
                }

                // 建立時間
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(formatDate(task.createdAt))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 來源統計
                HStack(spacing: 8) {
                    ForEach(Array(task.sourceStats.keys), id: \.self) { source in
                        if let count = task.sourceStats[source] {
                            HStack(spacing: 2) {
                                Image(systemName: source.iconName)
                                    .font(.system(size: 11))
                                Text("\(count)")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
    }

    private func statusBadge(_ task: ClipTask) -> some View {
        HStack(spacing: 4) {
            Image(systemName: task.status.iconName)
            Text(task.status.rawValue)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor(task).opacity(0.2))
        .foregroundStyle(statusColor(task))
        .cornerRadius(6)
    }

    private func statusColor(_ task: ClipTask) -> Color {
        switch task.status {
        case .active: return .green
        case .paused: return .orange
        case .completed: return .gray
        }
    }

    // MARK: - Items List

    private func taskItemsList(_ task: ClipTask) -> some View {
        List {
            ForEach(task.items) { item in
                TaskItemRow(item: item, taskId: task.id)
                    .listRowSeparator(.visible)
            }
            .onMove { source, destination in
                taskManager.moveTaskItem(in: task, from: source, to: destination)
            }
        }
        .listStyle(.plain)
    }

    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("尚無收集項目")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("從剪貼簿歷史加入項目到此任務")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private func taskFooter(_ task: ClipTask) -> some View {
        HStack {
            // 刪除按鈕
            Button(role: .destructive) {
                taskManager.deleteTask(task)
            } label: {
                Label("刪除", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)

            // 完成按鈕
            if task.status != .completed {
                Button {
                    taskManager.completeTask(task)
                } label: {
                    Label("完成任務", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // 匯出按鈕
            Button {
                taskManager.copyMarkdownToClipboard(task)
            } label: {
                Label("複製 Markdown", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Button {
                taskManager.exportTaskToFile(task)
            } label: {
                Label("匯出", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Task Item Row

struct TaskItemRow: View {
    let item: TaskItem
    let taskId: UUID
    @ObservedObject var taskManager = TaskManager.shared
    @State private var isHovering = false
    @State private var editingNote = false
    @State private var editedNote = ""

    private var task: ClipTask? {
        taskManager.tasks.first { $0.id == taskId }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 來源圖示
            Image(systemName: item.source.iconName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // 內容
                Text(item.content)
                    .font(.system(size: 13))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // 時間
                    Text(formatTime(item.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    // 來源標籤
                    Text(item.source.rawValue)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)

                    // 備註
                    if !item.note.isEmpty {
                        Text("📝 \(item.note)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 操作按鈕（常駐顯示）
            if let task = task {
                HStack(spacing: 8) {
                    Button {
                        editedNote = item.note
                        editingNote = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("編輯備註")

                    Button {
                        // 複製內容
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(item.content, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("複製內容")

                    Button(role: .destructive) {
                        taskManager.removeItemFromTask(item, task: task)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("移除")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $editingNote) {
            noteEditSheet
        }
    }

    private var noteEditSheet: some View {
        VStack(spacing: 16) {
            Text("編輯備註")
                .font(.headline)

            TextEditor(text: $editedNote)
                .frame(height: 100)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("取消") {
                    editingNote = false
                }
                .buttonStyle(.bordered)

                Button("儲存") {
                    if let task = task {
                        taskManager.updateItemNote(item, task: task, note: editedNote)
                    }
                    editingNote = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TaskModeView()
}
