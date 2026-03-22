import Foundation

/// 用於 App 和 Widget 之間共享資料
struct SharedData {
    static let appGroupIdentifier = "group.com.clipstash.app"
    static let itemsKey = "shared_clip_items"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func saveItems(_ items: [ClipItem]) {
        guard let defaults = sharedDefaults,
              let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: itemsKey)
    }

    static func loadItems() -> [ClipItem] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: itemsKey),
              let items = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return []
        }
        return items
    }
}
