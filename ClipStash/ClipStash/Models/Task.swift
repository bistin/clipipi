import Foundation

/// 內容來源類型
enum ContentSource: String, Codable, CaseIterable {
    case slack = "Slack"
    case jira = "Jira"
    case quip = "Quip"
    case notion = "Notion"
    case github = "GitHub"
    case unknown = "其他"

    var iconName: String {
        switch self {
        case .slack: return "bubble.left.and.bubble.right"
        case .jira: return "ticket"
        case .quip: return "doc.richtext"
        case .notion: return "book.closed"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .unknown: return "link"
        }
    }

    /// 從 URL 偵測來源
    static func detect(from content: String) -> ContentSource {
        let lowercased = content.lowercased()

        if lowercased.contains("slack.com") || lowercased.contains("slack://") {
            return .slack
        }
        if lowercased.contains("atlassian.net") || lowercased.contains("jira") {
            return .jira
        }
        if lowercased.contains("quip.com") {
            return .quip
        }
        if lowercased.contains("notion.so") || lowercased.contains("notion.site") {
            return .notion
        }
        if lowercased.contains("github.com") || lowercased.contains("githubusercontent.com") {
            return .github
        }

        return .unknown
    }

    /// 從 Slack URL 解析 Channel 名稱
    static func parseSlackChannel(from url: String) -> String? {
        // 格式: https://xxx.slack.com/archives/C12345678
        // 或: https://xxx.slack.com/messages/channel-name
        guard url.lowercased().contains("slack.com") else { return nil }

        if let range = url.range(of: "/archives/") {
            let afterArchives = url[range.upperBound...]
            return String(afterArchives.prefix(while: { $0 != "/" && $0 != "?" }))
        }

        if let range = url.range(of: "/messages/") {
            let afterMessages = url[range.upperBound...]
            return String(afterMessages.prefix(while: { $0 != "/" && $0 != "?" }))
        }

        return nil
    }
}

/// 任務狀態
enum TaskStatus: String, Codable {
    case active = "進行中"
    case paused = "暫停"
    case completed = "已完成"

    var iconName: String {
        switch self {
        case .active: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

/// 任務項目 - 關聯到任務的剪貼簿項目
struct TaskItem: Identifiable, Codable {
    let id: UUID
    let clipItemId: UUID    // 對應的 ClipItem ID
    let content: String     // 內容預覽
    let source: ContentSource
    let timestamp: Date
    var note: String        // 備註

    init(id: UUID = UUID(), clipItemId: UUID, content: String, source: ContentSource, timestamp: Date = Date(), note: String = "") {
        self.id = id
        self.clipItemId = clipItemId
        self.content = content
        self.source = source
        self.timestamp = timestamp
        self.note = note
    }
}

/// 任務模型（使用 ClipTask 避免與 Swift.Task 衝突）
struct ClipTask: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var slackChannel: String    // Slack channel 名稱或 ID
    var status: TaskStatus
    var items: [TaskItem]       // 收集的項目
    let createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), name: String, slackChannel: String = "", status: TaskStatus = .active, items: [TaskItem] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.slackChannel = slackChannel
        self.status = status
        self.items = items
        self.createdAt = createdAt
        self.completedAt = nil
    }

    /// 各來源的項目統計
    var sourceStats: [ContentSource: Int] {
        var stats: [ContentSource: Int] = [:]
        for item in items {
            stats[item.source, default: 0] += 1
        }
        return stats
    }

    /// 匯出為 Markdown
    func exportToMarkdown() -> String {
        var markdown = """
        # \(name)

        **Slack Channel**: \(slackChannel.isEmpty ? "未設定" : slackChannel)
        **狀態**: \(status.rawValue)
        **建立時間**: \(formatDate(createdAt))
        """

        if let completedAt = completedAt {
            markdown += "\n**完成時間**: \(formatDate(completedAt))"
        }

        markdown += "\n\n---\n\n## 收集項目 (\(items.count))\n\n"

        // 按來源分組
        let grouped = Dictionary(grouping: items) { $0.source }

        for source in ContentSource.allCases {
            guard let sourceItems = grouped[source], !sourceItems.isEmpty else { continue }

            markdown += "### \(source.rawValue) (\(sourceItems.count))\n\n"

            for item in sourceItems {
                let preview = item.content.prefix(100)
                markdown += "- **\(formatDate(item.timestamp))**\n"
                markdown += "  ```\n  \(preview)\(item.content.count > 100 ? "..." : "")\n  ```\n"
                if !item.note.isEmpty {
                    markdown += "  > 備註: \(item.note)\n"
                }
                markdown += "\n"
            }
        }

        markdown += "\n---\n*匯出自 ClipStash*\n"

        return markdown
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh-Hant")
        return formatter.string(from: date)
    }

    // MARK: - Hashable

    static func == (lhs: ClipTask, rhs: ClipTask) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
