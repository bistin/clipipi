import SwiftUI

struct ClipItemRow: View {
    let item: ClipItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var relativeTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-Hant")
        formatter.unitsStyle = .full
        return formatter
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 類型圖示
            Image(systemName: item.type.iconName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            // 內容
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                // 時間或釘選狀態
                if item.isPinned {
                    Label("釘選", systemImage: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                } else {
                    Text(relativeTimeFormatter.localizedString(for: item.timestamp, relativeTo: Date()))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Hover 時顯示操作按鈕
            if isHovering {
                HStack(spacing: 4) {
                    // 貼上
                    Button(action: onPaste) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("貼上")

                    // 釘選/取消釘選
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "取消釘選" : "釘選")

                    // 刪除
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("刪除")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onPaste()
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ClipItemRow(
            item: ClipItem(content: "https://github.com/example/repo"),
            isSelected: false,
            onPaste: {},
            onTogglePin: {},
            onDelete: {}
        )
        ClipItemRow(
            item: ClipItem(content: "SELECT * FROM users WHERE id = 1;"),
            isSelected: true,
            onPaste: {},
            onTogglePin: {},
            onDelete: {}
        )
        ClipItemRow(
            item: ClipItem(content: "這是一段普通的文字內容，用於測試顯示效果。", isPinned: true),
            isSelected: false,
            onPaste: {},
            onTogglePin: {},
            onDelete: {}
        )
    }
    .frame(width: 320)
    .padding()
}
