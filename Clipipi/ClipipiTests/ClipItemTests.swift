import Testing
import Foundation
@testable import Clipipi

@Suite("ClipItem Tests")
struct ClipItemTests {

    // MARK: - Type Detection

    @Test("偵測 HTTP URL")
    func detectHttpUrl() {
        let type = ClipItem.detectType("https://www.apple.com")
        #expect(type == .url)
    }

    @Test("偵測 HTTP URL（有空白）")
    func detectUrlWithWhitespace() {
        let type = ClipItem.detectType("  https://example.com  ")
        #expect(type == .url)
    }

    @Test("非 URL scheme 不算 URL")
    func nonHttpSchemeIsNotUrl() {
        let type = ClipItem.detectType("ftp://files.example.com")
        #expect(type != .url)
    }

    @Test("偵測 Swift 程式碼")
    func detectSwiftCode() {
        let type = ClipItem.detectType("func hello() -> String { return \"hi\" }")
        #expect(type == .code)
    }

    @Test("偵測 Python 程式碼")
    func detectPythonCode() {
        let type = ClipItem.detectType("def calculate(x, y):")
        #expect(type == .code)
    }

    @Test("偵測 shell 指令")
    func detectShellCommand() {
        let type = ClipItem.detectType("docker run -it ubuntu bash")
        #expect(type == .code)
    }

    @Test("偵測 Dockerfile")
    func detectDockerfile() {
        let type = ClipItem.detectType("FROM node:18\nRUN npm install")
        #expect(type == .code)
    }

    @Test("一般文字")
    func detectPlainText() {
        let type = ClipItem.detectType("今天天氣真好")
        #expect(type == .text)
    }

    @Test("空字串是文字")
    func emptyStringIsText() {
        let type = ClipItem.detectType("")
        #expect(type == .text)
    }

    // MARK: - Initialization

    @Test("文字初始化自動偵測類型")
    func textInitAutoDetectsType() {
        let item = ClipItem(content: "https://github.com")
        #expect(item.type == .url)
        #expect(item.isPinned == false)
        #expect(item.tags.isEmpty)
        #expect(item.imageData == nil)
    }

    @Test("圖片初始化")
    func imageInit() {
        let data = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let item = ClipItem(imageData: data)
        #expect(item.type == .image)
        #expect(item.content == "[圖片]")
        #expect(item.imageData == data)
    }

    @Test("帶標籤初始化")
    func initWithTags() {
        let item = ClipItem(content: "test", tags: ["work", "important"])
        #expect(item.tags == ["work", "important"])
    }

    @Test("帶任務 ID 初始化")
    func initWithTaskId() {
        let taskId = UUID()
        let item = ClipItem(content: "test", taskId: taskId)
        #expect(item.taskId == taskId)
    }

    // MARK: - Content Source Detection (via detectedSource)

    @Test("偵測 Slack 來源")
    func detectSlackSource() {
        let item = ClipItem(content: "https://myteam.slack.com/archives/C12345")
        #expect(item.detectedSource == .slack)
    }

    @Test("偵測 GitHub 來源")
    func detectGithubSource() {
        let item = ClipItem(content: "https://github.com/user/repo/pull/1")
        #expect(item.detectedSource == .github)
    }

    @Test("一般文字來源是 unknown")
    func plainTextSourceIsUnknown() {
        let item = ClipItem(content: "just some text")
        #expect(item.detectedSource == .unknown)
    }

    // MARK: - Codable

    @Test("JSON 編解碼")
    func jsonCodable() throws {
        let item = ClipItem(content: "test content", isPinned: true, tags: ["tag1"])
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipItem.self, from: data)
        #expect(decoded.id == item.id)
        #expect(decoded.content == item.content)
        #expect(decoded.isPinned == true)
        #expect(decoded.tags == ["tag1"])
        #expect(decoded.type == item.type)
    }

    // MARK: - Icon Names

    @Test("各類型 icon 名稱")
    func clipTypeIconNames() {
        #expect(ClipItem.ClipType.text.iconName == "doc.text")
        #expect(ClipItem.ClipType.url.iconName == "link")
        #expect(ClipItem.ClipType.code.iconName == "chevron.left.forwardslash.chevron.right")
        #expect(ClipItem.ClipType.image.iconName == "photo")
    }

    // MARK: - Display Names

    @Test("各類型 displayName")
    func clipTypeDisplayNames() {
        #expect(ClipItem.ClipType.text.displayName == "文字")
        #expect(ClipItem.ClipType.url.displayName == "網址")
        #expect(ClipItem.ClipType.code.displayName == "程式碼")
        #expect(ClipItem.ClipType.image.displayName == "圖片")
    }

    // MARK: - OCR Text

    @Test("圖片初始化含 OCR 文字")
    func imageInitWithOcrText() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let item = ClipItem(imageData: data, ocrText: "recognized text")
        #expect(item.ocrText == "recognized text")
    }

    @Test("文字初始化 OCR 為 nil")
    func textInitOcrIsNil() {
        let item = ClipItem(content: "hello")
        #expect(item.ocrText == nil)
    }

    @Test("OCR 文字可 JSON 編解碼")
    func ocrTextCodable() throws {
        let item = ClipItem(imageData: Data([0x00]), ocrText: "OCR result")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipItem.self, from: data)
        #expect(decoded.ocrText == "OCR result")
    }
}
