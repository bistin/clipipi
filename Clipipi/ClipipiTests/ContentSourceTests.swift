import Testing
@testable import Clipipi

@Suite("ContentSource Tests")
struct ContentSourceTests {

    // MARK: - Source Detection

    @Test("偵測 Slack URL")
    func detectSlack() {
        #expect(ContentSource.detect(from: "https://myteam.slack.com/archives/C123") == .slack)
    }

    @Test("偵測 slack:// protocol")
    func detectSlackProtocol() {
        #expect(ContentSource.detect(from: "slack://channel?team=T123&id=C456") == .slack)
    }

    @Test("偵測 Jira（atlassian.net）")
    func detectJiraAtlassian() {
        #expect(ContentSource.detect(from: "https://myteam.atlassian.net/browse/PROJ-123") == .jira)
    }

    @Test("偵測 Jira（含 jira 字串）")
    func detectJiraKeyword() {
        #expect(ContentSource.detect(from: "https://jira.company.com/browse/TASK-1") == .jira)
    }

    @Test("偵測 Quip")
    func detectQuip() {
        #expect(ContentSource.detect(from: "https://myteam.quip.com/abc123/Document") == .quip)
    }

    @Test("偵測 Notion（.so）")
    func detectNotionSo() {
        #expect(ContentSource.detect(from: "https://www.notion.so/workspace/page-id") == .notion)
    }

    @Test("偵測 Notion（.site）")
    func detectNotionSite() {
        #expect(ContentSource.detect(from: "https://mysite.notion.site/page") == .notion)
    }

    @Test("偵測 GitHub")
    func detectGithub() {
        #expect(ContentSource.detect(from: "https://github.com/user/repo") == .github)
    }

    @Test("偵測 githubusercontent")
    func detectGithubusercontent() {
        #expect(ContentSource.detect(from: "https://raw.githubusercontent.com/user/repo/main/file") == .github)
    }

    @Test("無法辨識的 URL 回傳 unknown")
    func unknownUrl() {
        #expect(ContentSource.detect(from: "https://www.google.com") == .unknown)
    }

    @Test("一般文字回傳 unknown")
    func plainText() {
        #expect(ContentSource.detect(from: "hello world") == .unknown)
    }

    @Test("大小寫不敏感")
    func caseInsensitive() {
        #expect(ContentSource.detect(from: "HTTPS://GITHUB.COM/user/repo") == .github)
    }

    // MARK: - Slack Channel Parsing

    @Test("解析 /archives/ 格式")
    func parseArchivesChannel() {
        let channel = ContentSource.parseSlackChannel(from: "https://team.slack.com/archives/C12345678")
        #expect(channel == "C12345678")
    }

    @Test("解析 /messages/ 格式")
    func parseMessagesChannel() {
        let channel = ContentSource.parseSlackChannel(from: "https://team.slack.com/messages/general")
        #expect(channel == "general")
    }

    @Test("解析帶尾部斜線的 URL")
    func parseChannelWithTrailingSlash() {
        let channel = ContentSource.parseSlackChannel(from: "https://team.slack.com/archives/C123/")
        #expect(channel == "C123")
    }

    @Test("解析帶 query string 的 URL")
    func parseChannelWithQuery() {
        let channel = ContentSource.parseSlackChannel(from: "https://team.slack.com/archives/C123?thread_ts=123")
        #expect(channel == "C123")
    }

    @Test("非 Slack URL 回傳 nil")
    func nonSlackUrlReturnsNil() {
        let channel = ContentSource.parseSlackChannel(from: "https://github.com/user/repo")
        #expect(channel == nil)
    }

    @Test("Slack URL 但無 channel 路徑回傳 nil")
    func slackUrlWithoutChannelPath() {
        let channel = ContentSource.parseSlackChannel(from: "https://team.slack.com/")
        #expect(channel == nil)
    }

    // MARK: - Icon Names

    @Test("各來源 icon 名稱不為空")
    func iconNamesAreNotEmpty() {
        for source in ContentSource.allCases {
            #expect(!source.iconName.isEmpty)
        }
    }
}
