import AppKit

/// 依 bundle id 查 App icon，結果用 dictionary 快取避免每次 row render 都打 LaunchServices。
enum AppIconLookup {
    @MainActor
    private static var cache: [String: NSImage?] = [:]

    @MainActor
    static func icon(forBundleId bundleId: String) -> NSImage? {
        if let cached = cache[bundleId] { return cached }

        let image: NSImage?
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = nil
        }
        cache[bundleId] = image
        return image
    }

    @MainActor
    static func appName(forBundleId bundleId: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }
}
