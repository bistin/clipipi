import Foundation
import AppKit
import Combine

@MainActor
final class TaskManager: ObservableObject, Sendable {
    static let shared = TaskManager()

    @Published private(set) var tasks: [ClipTask] = []
    @Published var activeTaskId: UUID?           // 當前作用中的收集
    @Published var isTaskModeEnabled: Bool = false
    @Published var isAutoCollectEnabled: Bool = false {
        didSet { savePreferences() }
    }
    /// 開啟時列表只顯示當前收集的項目
    @Published var isCollectionFilterActive: Bool = false {
        didSet { savePreferences() }
    }

    private let userDefaultsKey = "clip_stash_tasks"
    private let preferencesKey = "clip_stash_task_preferences"

    // 當前作用中的任務
    var activeTask: ClipTask? {
        guard let id = activeTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    // 進行中的任務
    var activeTasks: [ClipTask] {
        tasks.filter { $0.status == .active || $0.status == .paused }
    }

    // 已完成的任務
    var completedTasks: [ClipTask] {
        tasks.filter { $0.status == .completed }
    }

    private init() {
        loadTasks()
        loadPreferences()
    }

    /// 測試用初始化（不讀取 UserDefaults）
    init(forTesting tasks: [ClipTask] = []) {
        self.tasks = tasks
        self.activeTaskId = tasks.first(where: { $0.status == .active })?.id
        self.isAutoCollectEnabled = false
        self.isCollectionFilterActive = false
    }

    // MARK: - Task Management

    /// 建立新收集（名稱為必填）
    func createTask(name: String, slackChannel: String = "") -> ClipTask? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let task = ClipTask(name: trimmed, slackChannel: slackChannel)
        tasks.insert(task, at: 0)
        activeTaskId = task.id
        saveTasks()
        return task
    }

    /// 設為當前收集（自動收集的目標，不改變列表檢視）
    func setActiveCollection(_ task: ClipTask) {
        activeTaskId = task.id
    }

    /// 切換「只看此收集」
    func toggleCollectionFilter() {
        guard activeTaskId != nil else { return }
        isCollectionFilterActive.toggle()
    }

    /// 回到全部歷史檢視
    func showAllHistory() {
        isCollectionFilterActive = false
    }

    /// 刪除任務
    func deleteTask(_ task: ClipTask) {
        tasks.removeAll { $0.id == task.id }
        if activeTaskId == task.id {
            activeTaskId = activeTasks.first?.id
        }
        saveTasks()
    }

    /// 切換作用中的任務
    func setActiveTask(_ task: ClipTask?) {
        activeTaskId = task?.id
    }

    /// 更新任務名稱
    func updateTaskName(_ task: ClipTask, name: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].name = name
        saveTasks()
    }

    /// 更新 Slack Channel
    func updateSlackChannel(_ task: ClipTask, channel: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].slackChannel = channel
        saveTasks()
    }

    /// 變更任務狀態
    func setTaskStatus(_ task: ClipTask, status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = status
        if status == .completed {
            tasks[index].completedAt = Date()
        }
        saveTasks()
    }

    /// 完成任務
    func completeTask(_ task: ClipTask) {
        setTaskStatus(task, status: .completed)
        if activeTaskId == task.id {
            activeTaskId = activeTasks.first?.id
        }
    }

    /// 暫停任務
    func pauseTask(_ task: ClipTask) {
        setTaskStatus(task, status: .paused)
    }

    /// 繼續任務
    func resumeTask(_ task: ClipTask) {
        setTaskStatus(task, status: .active)
    }

    // MARK: - Item Management

    /// 加入項目到收集（同步 ClipItem.taskId 與 TaskItem）
    func addItemToTask(_ clipItem: ClipItem, task: ClipTask, note: String = "") {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        ClipboardManager.shared.setTaskId(task.id, for: clipItem)

        let source = ContentSource.detect(from: clipItem.content)

        // 如果是 Slack URL 且任務沒有設定 channel，嘗試解析
        if source == .slack && tasks[index].slackChannel.isEmpty {
            if let channel = ContentSource.parseSlackChannel(from: clipItem.content) {
                tasks[index].slackChannel = channel
            }
        }

        if tasks[index].items.contains(where: { $0.clipItemId == clipItem.id }) {
            if !note.isEmpty,
               let itemIndex = tasks[index].items.firstIndex(where: { $0.clipItemId == clipItem.id }) {
                tasks[index].items[itemIndex].note = note
            }
            saveTasks()
            return
        }

        let taskItem = TaskItem(
            clipItemId: clipItem.id,
            content: clipItem.content,
            source: source,
            note: note
        )

        tasks[index].items.append(taskItem)
        saveTasks()
    }

    /// 自動收集時同步新項目到當前收集
    func syncNewClipItemToActiveCollection(_ clipItem: ClipItem) {
        guard isAutoCollectEnabled, let task = activeTask else { return }
        addItemToTask(clipItem, task: task)
    }

    /// 從任務移除項目
    func removeItemFromTask(_ taskItem: TaskItem, task: ClipTask) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].items.removeAll { $0.id == taskItem.id }
        if let clipItem = ClipboardManager.shared.item(withId: taskItem.clipItemId) {
            ClipboardManager.shared.clearTaskId(for: clipItem)
        }
        saveTasks()
    }

    /// 從收集移除（依 ClipItem）
    func removeClipItemFromCollection(_ clipItem: ClipItem) {
        if let taskId = clipItem.taskId,
           let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[taskIndex].items.removeAll { $0.clipItemId == clipItem.id }
            saveTasks()
        }
        ClipboardManager.shared.clearTaskId(for: clipItem)
    }

    /// 更新項目備註
    func updateItemNote(_ taskItem: TaskItem, task: ClipTask, note: String) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
              let itemIndex = tasks[taskIndex].items.firstIndex(where: { $0.id == taskItem.id }) else { return }
        tasks[taskIndex].items[itemIndex].note = note
        saveTasks()
    }

    /// 重新排序任務內的項目
    func moveTaskItem(in task: ClipTask, from source: IndexSet, to destination: Int) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].items.move(fromOffsets: source, toOffset: destination)
        saveTasks()
    }

    // MARK: - Quick Add (從剪貼簿快速加入到當前任務)

    /// 快速加入到當前任務
    func quickAddToActiveTask(_ clipItem: ClipItem) {
        guard let task = activeTask else { return }
        addItemToTask(clipItem, task: task)
    }

    /// 檢查項目是否已在任務中
    func isItemInTask(_ clipItem: ClipItem, task: ClipTask) -> Bool {
        clipItem.taskId == task.id || task.items.contains { $0.clipItemId == clipItem.id }
    }

    /// 收集中的項目數量（以 ClipItem.taskId 為準）
    func collectionItemCount(for taskId: UUID) -> Int {
        ClipboardManager.shared.items.filter { $0.taskId == taskId }.count
    }

    // MARK: - Export

    /// 匯出任務為 Markdown
    func exportTaskToMarkdown(_ task: ClipTask) -> String {
        task.exportToMarkdown()
    }

    /// 匯出任務到檔案
    func exportTaskToFile(_ task: ClipTask) {
        let markdown = task.exportToMarkdown()

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "\(task.name).md"
        savePanel.title = "匯出任務"
        savePanel.message = "選擇儲存位置"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("匯出失敗: \(error)")
            }
        }
    }

    /// 複製 Markdown 到剪貼簿
    func copyMarkdownToClipboard(_ task: ClipTask) {
        let markdown = task.exportToMarkdown()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }

    // MARK: - Persistence

    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ClipTask].self, from: data) {
            tasks = decoded
            // 恢復到第一個進行中的任務
            activeTaskId = activeTasks.first?.id
        }
    }

    // MARK: - Preferences

    private struct TaskPreferences: Codable {
        var isAutoCollectEnabled: Bool
    }

    private func savePreferences() {
        let prefs = TaskPreferences(isAutoCollectEnabled: isAutoCollectEnabled)
        if let encoded = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }

    private func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let prefs = try? JSONDecoder().decode(TaskPreferences.self, from: data) else {
            return
        }
        isAutoCollectEnabled = prefs.isAutoCollectEnabled
        // 列表永遠從全部歷史開始，避免一開啟就像進入任務清單
        isCollectionFilterActive = false
    }
}
