import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject, Sendable {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate(current: String)
        case updateAvailable(latest: String, current: String, releaseURL: URL)
        case failed(message: String)
    }

    @Published private(set) var state: State = .idle

    private let repo = "bistin/clipipi"

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    func check() {
        if case .checking = state { return }
        state = .checking
        let current = currentVersion
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            state = .failed(message: "URL 無效")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        Task { [repo] in
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    self.state = .failed(message: "無回應")
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    self.state = .failed(message: "HTTP \(http.statusCode)")
                    return
                }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latest = Self.normalize(release.tagName)
                let releaseURL = URL(string: release.htmlUrl)
                    ?? URL(string: "https://github.com/\(repo)/releases/latest")!
                if Self.compare(current, latest) == .orderedAscending {
                    self.state = .updateAvailable(latest: latest, current: current, releaseURL: releaseURL)
                } else {
                    self.state = .upToDate(current: current)
                }
            } catch {
                self.state = .failed(message: error.localizedDescription)
            }
        }
    }

    func openReleasePage() {
        if case .updateAvailable(_, _, let url) = state {
            NSWorkspace.shared.open(url)
        } else {
            if let url = URL(string: "https://github.com/\(repo)/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    static func normalize(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s.removeFirst()
        }
        return s
    }

    /// 依小數點分段比較整數（忽略 pre-release suffix）
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = parts(a)
        let rhs = parts(b)
        let length = max(lhs.count, rhs.count)
        for i in 0..<length {
            let li = i < lhs.count ? lhs[i] : 0
            let ri = i < rhs.count ? rhs[i] : 0
            if li < ri { return .orderedAscending }
            if li > ri { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func parts(_ version: String) -> [Int] {
        let core = version.split(separator: "-", maxSplits: 1).first.map(String.init) ?? version
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: String
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }
}
