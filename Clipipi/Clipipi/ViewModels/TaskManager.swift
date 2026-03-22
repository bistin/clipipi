import Foundation
import AppKit
import Combine

@MainActor
final class TaskManager: ObservableObject, Sendable {
    static let shared = TaskManager()

    @Published private(set) var tasks: [ClipTask] = []
    @Published var activeTaskId: UUID?           // 當前作用中的任務
    @Published var isTaskModeEnabled: Bool = false

    private let userDefaultsKey = "clip_stash_tasks"
    private let maxActiveTasks = 3

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
    }

    /// 測試用初始化（不讀取 UserDefaults）
    init(forTesting tasks: [ClipTask] = []) {
        self.tasks = tasks
        self.activeTaskId = tasks.first(where: { $0.status == .active })?.id
    }

    // MARK: - Task Management

    /// 建立新任務
    func createTask(name: String, slackChannel: String = "") -> ClipTask? {
        // 限制同時進行中的任務數量
        guard activeTasks.count < maxActiveTasks else {
            return nil
        }

        let task = ClipTask(name: name, slackChannel: slackChannel)
        tasks.insert(task, at: 0)
        activeTaskId = task.id
        saveTasks()
        return task
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

    /// 加入項目到任務
    func addItemToTask(_ clipItem: ClipItem, task: ClipTask, note: String = "") {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let source = ContentSource.detect(from: clipItem.content)

        // 如果是 Slack URL 且任務沒有設定 channel，嘗試解析
        if source == .slack && tasks[index].slackChannel.isEmpty {
            if let channel = ContentSource.parseSlackChannel(from: clipItem.content) {
                tasks[index].slackChannel = channel
            }
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

    /// 從任務移除項目
    func removeItemFromTask(_ taskItem: TaskItem, task: ClipTask) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[taskIndex].items.removeAll { $0.id == taskItem.id }
        saveTasks()
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
        task.items.contains { $0.clipItemId == clipItem.id }
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
}
