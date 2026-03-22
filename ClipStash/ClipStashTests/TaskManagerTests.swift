import Testing
import Foundation
@testable import ClipStash

@Suite("TaskManager Tests")
@MainActor
struct TaskManagerTests {

    // MARK: - Helper

    private func makeManager(tasks: [ClipTask] = []) -> TaskManager {
        TaskManager(forTesting: tasks)
    }

    // MARK: - Task Creation

    @Test("建立任務")
    func createTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Test Task", slackChannel: "general")

        #expect(task != nil)
        #expect(task?.name == "Test Task")
        #expect(task?.slackChannel == "general")
        #expect(manager.tasks.count == 1)
        #expect(manager.activeTaskId == task?.id)
    }

    @Test("建立任務上限 3 個")
    func createTaskLimit() {
        let manager = makeManager()
        _ = manager.createTask(name: "Task 1")
        _ = manager.createTask(name: "Task 2")
        _ = manager.createTask(name: "Task 3")
        let fourth = manager.createTask(name: "Task 4")

        #expect(fourth == nil)
        #expect(manager.tasks.count == 3)
    }

    @Test("已完成的任務不算在上限內")
    func completedTasksNotCountedInLimit() {
        let completed = ClipTask(name: "Done", status: .completed)
        let manager = makeManager(tasks: [completed])
        _ = manager.createTask(name: "Task 1")
        _ = manager.createTask(name: "Task 2")
        _ = manager.createTask(name: "Task 3")

        #expect(manager.tasks.count == 4)
    }

    // MARK: - Task Deletion

    @Test("刪除任務")
    func deleteTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "To Delete")!
        manager.deleteTask(task)

        #expect(manager.tasks.isEmpty)
    }

    @Test("刪除作用中任務會切換 activeTaskId")
    func deleteActiveTaskSwitchesActive() {
        let manager = makeManager()
        let task1 = manager.createTask(name: "Task 1")!
        _ = manager.createTask(name: "Task 2")
        manager.setActiveTask(task1)
        manager.deleteTask(task1)

        #expect(manager.activeTaskId != task1.id)
    }

    // MARK: - Task Status

    @Test("完成任務")
    func completeTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        manager.completeTask(task)

        #expect(manager.tasks[0].status == .completed)
        #expect(manager.tasks[0].completedAt != nil)
    }

    @Test("暫停任務")
    func pauseTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        manager.pauseTask(task)

        #expect(manager.tasks[0].status == .paused)
    }

    @Test("繼續任務")
    func resumeTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        manager.pauseTask(task)
        manager.resumeTask(manager.tasks[0])

        #expect(manager.tasks[0].status == .active)
    }

    @Test("完成作用中任務後切換 active")
    func completeActiveTaskSwitchesActive() {
        let manager = makeManager()
        _ = manager.createTask(name: "Task 1")
        let task2 = manager.createTask(name: "Task 2")!
        manager.setActiveTask(task2)
        manager.completeTask(task2)

        #expect(manager.activeTaskId != task2.id)
    }

    // MARK: - Computed Properties

    @Test("activeTasks 回傳進行中和暫停的")
    func activeTasksFilter() {
        let tasks = [
            ClipTask(name: "Active", status: .active),
            ClipTask(name: "Paused", status: .paused),
            ClipTask(name: "Completed", status: .completed),
        ]
        let manager = makeManager(tasks: tasks)

        #expect(manager.activeTasks.count == 2)
    }

    @Test("completedTasks 回傳已完成的")
    func completedTasksFilter() {
        let tasks = [
            ClipTask(name: "Active", status: .active),
            ClipTask(name: "Completed", status: .completed),
        ]
        let manager = makeManager(tasks: tasks)

        #expect(manager.completedTasks.count == 1)
        #expect(manager.completedTasks[0].name == "Completed")
    }

    @Test("activeTask 回傳當前作用中任務")
    func activeTaskProperty() {
        let task = ClipTask(name: "Active")
        let manager = makeManager(tasks: [task])
        manager.setActiveTask(task)

        #expect(manager.activeTask?.id == task.id)
    }

    @Test("無 activeTaskId 時 activeTask 為 nil")
    func activeTaskNil() {
        let manager = makeManager()
        #expect(manager.activeTask == nil)
    }

    // MARK: - Task Updates

    @Test("更新任務名稱")
    func updateTaskName() {
        let manager = makeManager()
        let task = manager.createTask(name: "Old Name")!
        manager.updateTaskName(task, name: "New Name")

        #expect(manager.tasks[0].name == "New Name")
    }

    @Test("更新 Slack Channel")
    func updateSlackChannel() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        manager.updateSlackChannel(task, channel: "#general")

        #expect(manager.tasks[0].slackChannel == "#general")
    }

    // MARK: - Item Management

    @Test("加入項目到任務")
    func addItemToTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        let clipItem = ClipItem(content: "https://github.com/user/repo")

        manager.addItemToTask(clipItem, task: task)

        #expect(manager.tasks[0].items.count == 1)
        #expect(manager.tasks[0].items[0].source == .github)
    }

    @Test("Slack URL 自動填入 channel")
    func slackUrlAutoFillsChannel() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        let clipItem = ClipItem(content: "https://team.slack.com/archives/C12345")

        manager.addItemToTask(clipItem, task: task)

        #expect(manager.tasks[0].slackChannel == "C12345")
    }

    @Test("已有 channel 不覆蓋")
    func existingChannelNotOverwritten() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task", slackChannel: "existing")!
        let clipItem = ClipItem(content: "https://team.slack.com/archives/C99999")

        manager.addItemToTask(clipItem, task: task)

        #expect(manager.tasks[0].slackChannel == "existing")
    }

    @Test("從任務移除項目")
    func removeItemFromTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        let clipItem = ClipItem(content: "test")
        manager.addItemToTask(clipItem, task: task)

        let taskItem = manager.tasks[0].items[0]
        manager.removeItemFromTask(taskItem, task: manager.tasks[0])

        #expect(manager.tasks[0].items.isEmpty)
    }

    @Test("更新項目備註")
    func updateItemNote() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        let clipItem = ClipItem(content: "test")
        manager.addItemToTask(clipItem, task: task)

        let taskItem = manager.tasks[0].items[0]
        manager.updateItemNote(taskItem, task: manager.tasks[0], note: "important!")

        #expect(manager.tasks[0].items[0].note == "important!")
    }

    @Test("quickAddToActiveTask 加入到作用中任務")
    func quickAddToActiveTask() {
        let manager = makeManager()
        _ = manager.createTask(name: "Active Task")
        let clipItem = ClipItem(content: "quick add")

        manager.quickAddToActiveTask(clipItem)

        #expect(manager.tasks[0].items.count == 1)
    }

    @Test("無作用中任務時 quickAdd 不崩潰")
    func quickAddWithNoActiveTask() {
        let manager = makeManager()
        let clipItem = ClipItem(content: "test")
        manager.quickAddToActiveTask(clipItem) // should not crash
        #expect(manager.tasks.isEmpty)
    }

    @Test("isItemInTask 檢查項目是否在任務中")
    func isItemInTask() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        let clipItem = ClipItem(content: "test")

        #expect(manager.isItemInTask(clipItem, task: manager.tasks[0]) == false)

        manager.addItemToTask(clipItem, task: task)

        #expect(manager.isItemInTask(clipItem, task: manager.tasks[0]) == true)
    }

    // MARK: - Item Reordering

    @Test("moveTaskItem 重新排序項目")
    func moveTaskItem() {
        let manager = makeManager()
        let task = manager.createTask(name: "Task")!
        manager.addItemToTask(ClipItem(content: "first"), task: task)
        manager.addItemToTask(ClipItem(content: "second"), task: manager.tasks[0])
        manager.addItemToTask(ClipItem(content: "third"), task: manager.tasks[0])

        // 把第一個移到最後
        manager.moveTaskItem(in: manager.tasks[0], from: IndexSet(integer: 0), to: 3)

        #expect(manager.tasks[0].items[0].content == "second")
        #expect(manager.tasks[0].items[1].content == "third")
        #expect(manager.tasks[0].items[2].content == "first")
    }

    // MARK: - Export

    @Test("exportTaskToMarkdown 回傳 Markdown")
    func exportMarkdown() {
        let manager = makeManager()
        let task = manager.createTask(name: "Export Test")!
        let md = manager.exportTaskToMarkdown(task)

        #expect(md.contains("Export Test"))
    }
}
