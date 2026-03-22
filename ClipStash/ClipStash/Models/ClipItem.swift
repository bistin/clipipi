import Foundation
import AppKit

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipType
    var isPinned: Bool
    var imageData: Data?  // 圖片資料
    var tags: [String]    // 標籤
    var taskId: UUID?     // 關聯的任務 ID（可選）
    var ocrText: String?  // OCR 辨識結果

    /// 偵測內容來源（Slack, Jira, Quip, etc.）
    var detectedSource: ContentSource {
        ContentSource.detect(from: content)
    }

    enum ClipType: String, Codable {
        case text
        case url
        case code
        case image

        var iconName: String {
            switch self {
            case .text: return "doc.text"
            case .url: return "link"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .image: return "photo"
            }
        }

        var displayName: String {
            switch self {
            case .text: return "文字"
            case .url: return "網址"
            case .code: return "程式碼"
            case .image: return "圖片"
            }
        }
    }

    // 文字初始化
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isPinned: Bool = false, tags: [String] = [], taskId: UUID? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = ClipItem.detectType(content)
        self.isPinned = isPinned
        self.imageData = nil
        self.tags = tags
        self.taskId = taskId
        self.ocrText = nil
    }

    // 圖片初始化
    init(id: UUID = UUID(), imageData: Data, timestamp: Date = Date(), isPinned: Bool = false, tags: [String] = [], taskId: UUID? = nil, ocrText: String? = nil) {
        self.id = id
        self.content = "[圖片]"
        self.timestamp = timestamp
        self.type = .image
        self.isPinned = isPinned
        self.imageData = imageData
        self.tags = tags
        self.taskId = taskId
        self.ocrText = ocrText
    }

    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    static func detectType(_ content: String) -> ClipType {
        // URL 偵測
        if let url = URL(string: content.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https") {
            return .url
        }

        // 程式碼偵測
        let codeKeywords = [
            "func ", "def ", "fn ", "const ", "import ", "SELECT ", "=>", "|>",
            "kubectl ", "docker ", "git ", "class ", "struct ", "enum ",
            "if ", "else ", "for ", "while ", "return ", "var ", "let ",
            "public ", "private ", "protected ", "async ", "await ",
            "npm ", "yarn ", "brew ", "sudo ", "cd ", "ls ", "mkdir ",
            "export ", "FROM ", "RUN ", "CMD ", "COPY ", "ENV "
        ]

        for keyword in codeKeywords {
            if content.contains(keyword) {
                return .code
            }
        }

        return .text
    }

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        lhs.id == rhs.id
    }
}
