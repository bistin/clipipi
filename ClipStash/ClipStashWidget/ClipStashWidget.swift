import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ClipEntry {
        ClipEntry(date: Date(), items: [
            WidgetClipItem(content: "範例文字 1", type: "text"),
            WidgetClipItem(content: "範例文字 2", type: "text"),
            WidgetClipItem(content: "https://example.com", type: "url")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ClipEntry) -> ()) {
        let entry = ClipEntry(date: Date(), items: loadRecentItems())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipEntry>) -> ()) {
        let entry = ClipEntry(date: Date(), items: loadRecentItems())
        // 每 5 分鐘更新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadRecentItems() -> [WidgetClipItem] {
        guard let defaults = UserDefaults(suiteName: "group.com.clipstash.app"),
              let data = defaults.data(forKey: "shared_clip_items"),
              let items = try? JSONDecoder().decode([WidgetClipItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(5))
    }
}

// MARK: - Widget Entry

struct ClipEntry: TimelineEntry {
    let date: Date
    let items: [WidgetClipItem]
}

// 簡化版的 ClipItem，用於 Widget
struct WidgetClipItem: Codable, Identifiable {
    var id = UUID()
    let content: String
    let type: String

    var iconName: String {
        switch type {
        case "url": return "link"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "image": return "photo"
        default: return "doc.text"
        }
    }
}

// MARK: - Widget Views

struct ClipStashWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            mediumWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clipboard")
                    .font(.caption)
                Text("ClipStash")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)

            Divider()

            if entry.items.isEmpty {
                Text("尚無記錄")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(item.content)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clipboard")
                    .font(.subheadline)
                Text("ClipStash")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(entry.items.count) 筆")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if entry.items.isEmpty {
                Text("尚無剪貼簿記錄")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.items.prefix(4)) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(item.content)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct ClipStashWidget: Widget {
    let kind: String = "ClipStashWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClipStashWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ClipStash")
        .description("顯示最近的剪貼簿歷史")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ClipStashWidget()
} timeline: {
    ClipEntry(date: .now, items: [
        WidgetClipItem(content: "Hello World", type: "text"),
        WidgetClipItem(content: "https://github.com", type: "url"),
        WidgetClipItem(content: "func test() {}", type: "code")
    ])
}

#Preview(as: .systemMedium) {
    ClipStashWidget()
} timeline: {
    ClipEntry(date: .now, items: [
        WidgetClipItem(content: "Hello World", type: "text"),
        WidgetClipItem(content: "https://github.com", type: "url"),
        WidgetClipItem(content: "func test() {}", type: "code"),
        WidgetClipItem(content: "SELECT * FROM users", type: "code")
    ])
}
