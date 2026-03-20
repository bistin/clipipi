import Foundation

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let type: ClipType
    var isPinned: Bool

    enum ClipType: String, Codable {
        case text
        case url
        case code

        var iconName: String {
            switch self {
            case .text: return "doc.text"
            case .url: return "link"
            case .code: return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.type = ClipItem.detectType(content)
        self.isPinned = isPinned
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
