import Testing
import Foundation
@testable import ClipStash

@Suite("ClipTask Tests")
struct ClipTaskTests {

    // MARK: - Initialization

    @Test("預設初始化")
    func defaultInit() {
        let task = ClipTask(name: "Test Task")
        #expect(task.name == "Test Task")
        #expect(task.status == .active)
        #expect(task.slackChannel == "")
        #expect(task.items.isEmpty)
        #expect(task.completedAt == nil)
    }

    // MARK: - Source Stats

    @Test("空任務的 sourceStats 為空")
    func emptySourceStats() {
        let task = ClipTask(name: "Empty")
        #expect(task.sourceStats.isEmpty)
    }

    @Test("sourceStats 正確統計各來源")
    func sourceStatsCount() {
        let items = [
            TaskItem(clipItemId: UUID(), content: "https://team.slack.com/archives/C1", source: .slack),
            TaskItem(clipItemId: UUID(), content: "https://team.slack.com/archives/C2", source: .slack),
            TaskItem(clipItemId: UUID(), content: "https://github.com/repo", source: .github),
        ]
        let task = ClipTask(name: "Test", items: items)
        #expect(task.sourceStats[.slack] == 2)
        #expect(task.sourceStats[.github] == 1)
        #expect(task.sourceStats[.jira] == nil)
    }

    // MARK: - Markdown Export

    @Test("Markdown 包含任務名稱")
    func markdownContainsName() {
        let task = ClipTask(name: "My Task")
        let md = task.exportToMarkdown()
        #expect(md.contains("# My Task"))
    }

    @Test("Markdown 包含 Slack Channel")
    func markdownContainsChannel() {
        let task = ClipTask(name: "Task", slackChannel: "general")
        let md = task.exportToMarkdown()
        #expect(md.contains("general"))
    }

    @Test("未設定 Slack Channel 顯示未設定")
    func markdownShowsUnsetChannel() {
        let task = ClipTask(name: "Task")
        let md = task.exportToMarkdown()
        #expect(md.contains("未設定"))
    }

    @Test("Markdown 包含項目內容")
    func markdownContainsItemContent() {
        let items = [
            TaskItem(clipItemId: UUID(), content: "important note", source: .unknown),
        ]
        let task = ClipTask(name: "Task", items: items)
        let md = task.exportToMarkdown()
        #expect(md.contains("important note"))
    }

    @Test("Markdown 包含備註")
    func markdownContainsNote() {
        let items = [
            TaskItem(clipItemId: UUID(), content: "content", source: .unknown, note: "my note here"),
        ]
        let task = ClipTask(name: "Task", items: items)
        let md = task.exportToMarkdown()
        #expect(md.contains("my note here"))
    }

    @Test("Markdown 項目按來源分組")
    func markdownGroupsBySource() {
        let items = [
            TaskItem(clipItemId: UUID(), content: "slack msg", source: .slack),
            TaskItem(clipItemId: UUID(), content: "github pr", source: .github),
        ]
        let task = ClipTask(name: "Task", items: items)
        let md = task.exportToMarkdown()
        #expect(md.contains("### Slack"))
        #expect(md.contains("### GitHub"))
    }

    @Test("Markdown 包含 ClipStash 簽名")
    func markdownContainsSignature() {
        let task = ClipTask(name: "Task")
        let md = task.exportToMarkdown()
        #expect(md.contains("ClipStash"))
    }

    @Test("超過 100 字元的內容會截斷")
    func markdownTruncatesLongContent() {
        let longContent = String(repeating: "a", count: 150)
        let items = [
            TaskItem(clipItemId: UUID(), content: longContent, source: .unknown),
        ]
        let task = ClipTask(name: "Task", items: items)
        let md = task.exportToMarkdown()
        #expect(md.contains("..."))
    }

    // MARK: - TaskStatus

    @Test("狀態 rawValue")
    func statusRawValues() {
        #expect(TaskStatus.active.rawValue == "進行中")
        #expect(TaskStatus.paused.rawValue == "暫停")
        #expect(TaskStatus.completed.rawValue == "已完成")
    }

    @Test("狀態 icon 名稱不為空")
    func statusIconNames() {
        #expect(!TaskStatus.active.iconName.isEmpty)
        #expect(!TaskStatus.paused.iconName.isEmpty)
        #expect(!TaskStatus.completed.iconName.isEmpty)
    }

    // MARK: - Codable

    @Test("JSON 編解碼")
    func jsonCodable() throws {
        let task = ClipTask(name: "Test", slackChannel: "general")
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(ClipTask.self, from: data)
        #expect(decoded.id == task.id)
        #expect(decoded.name == task.name)
        #expect(decoded.slackChannel == task.slackChannel)
        #expect(decoded.status == task.status)
    }

    // MARK: - Equatable & Hashable

    @Test("相同 ID 視為相等")
    func equalityById() {
        let id = UUID()
        let task1 = ClipTask(id: id, name: "A")
        let task2 = ClipTask(id: id, name: "B")
        #expect(task1 == task2)
    }

    @Test("不同 ID 不相等")
    func inequalityByDifferentId() {
        let task1 = ClipTask(name: "A")
        let task2 = ClipTask(name: "A")
        #expect(task1 != task2)
    }
}
