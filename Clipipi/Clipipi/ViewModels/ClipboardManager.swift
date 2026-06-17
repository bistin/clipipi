import Foundation
import AppKit
import Combine

@MainActor
final class ClipboardManager: ObservableObject, Sendable {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipItem] = []
    @Published var searchText: String = ""
    @Published var selectedItemId: UUID?
    @Published var filterType: ClipItem.ClipType? = nil
    @Published var filterSource: ContentSource? = nil
    @Published var filterTag: String? = nil
    @Published var excludedBundleIds: Set<String> = [] {
        didSet { saveExcludedBundleIds() }
    }

    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private let userDefaultsKey = "clip_stash_items"
    private let excludedBundleIdsKey = "clip_stash_excluded_bundle_ids"

    /// 有些 App（如 1Password）會在剪貼簿加上這個 type 標記機密內容，要跳過記錄
    private static let concealedPasteboardTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
    ]

    /// 是否有任何篩選條件啟用
    var hasActiveFilters: Bool {
        filterType != nil || filterSource != nil || filterTag != nil
    }

    /// 清除所有篩選條件
    func clearFilters() {
        filterType = nil
        filterSource = nil
        filterTag = nil
    }

    var filteredItems: [ClipItem] {
        var result = items

        // 類型篩選
        if let type = filterType {
            result = result.filter { $0.type == type }
        }

        // 來源篩選
        if let source = filterSource {
            result = result.filter { $0.detectedSource == source }
        }

        // 標籤篩選
        if let tag = filterTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // 搜尋文字（支援正則）
        if !searchText.isEmpty {
            if searchText.hasPrefix("/") && searchText.hasSuffix("/") && searchText.count > 2 {
                // 正則模式
                let pattern = String(searchText.dropFirst().dropLast())
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = result.filter { item in
                        let searchTargets = [item.content, item.ocrText ?? ""]
                        return searchTargets.contains { target in
                            let range = NSRange(target.startIndex..., in: target)
                            return regex.firstMatch(in: target, range: range) != nil
                        }
                    }
                }
            } else {
                // 一般搜尋（內容 + 標籤 + OCR 文字）
                result = result.filter { item in
                    item.content.localizedCaseInsensitiveContains(searchText) ||
                    item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                    (item.ocrText?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        // 收集篩選
        if TaskManager.shared.isCollectionFilterActive,
           let taskId = TaskManager.shared.activeTaskId {
            result = result.filter { $0.taskId == taskId }
        }

        // 分離釘選
        let pinned = result.filter { $0.isPinned }
        let unpinned = result.filter { !$0.isPinned }
        return pinned + unpinned
    }

    var pinnedItems: [ClipItem] {
        filteredItems.filter { $0.isPinned }
    }

    var unpinnedItems: [ClipItem] {
        filteredItems.filter { !$0.isPinned }
    }

    /// 當前收集中、且未釘選的項目（全部歷史模式下顯示於頂部區塊）
    var activeCollectionUnpinnedItems: [ClipItem] {
        guard !TaskManager.shared.isCollectionFilterActive,
              let taskId = TaskManager.shared.activeTaskId else { return [] }
        return unpinnedItems.filter { $0.taskId == taskId }
    }

    /// 不屬於當前收集的未釘選項目
    var otherUnpinnedItems: [ClipItem] {
        guard !TaskManager.shared.isCollectionFilterActive,
              let taskId = TaskManager.shared.activeTaskId else {
            return unpinnedItems
        }
        return unpinnedItems.filter { $0.taskId != taskId }
    }

    var itemCount: Int {
        items.count
    }

    private init() {
        loadItems()
        loadExcludedBundleIds()
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    /// 測試用初始化（不啟動監聽、不讀取 UserDefaults）
    init(forTesting items: [ClipItem]) {
        self.items = items
        self.lastChangeCount = 0
    }

    // MARK: - Clipboard Monitoring

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 機密內容標記（1Password 之類會設這個 type）
        let availableTypes = Set(pasteboard.types ?? [])
        for concealed in ClipboardManager.concealedPasteboardTypes {
            if availableTypes.contains(concealed) { return }
        }

        // 來源 App（若在排除清單中就跳過）
        let frontApp = NSWorkspace.shared.frontmostApplication
        let sourceBundleId = frontApp?.bundleIdentifier
        let sourceAppName = frontApp?.localizedName
        if let bid = sourceBundleId, excludedBundleIds.contains(bid) { return }

        // 先檢查圖片
        if let imageData = getImageData(from: pasteboard) {
            addImageItem(imageData: imageData, sourceBundleId: sourceBundleId, sourceAppName: sourceAppName)
            return
        }

        // 檢查文字
        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        addItem(content: content, sourceBundleId: sourceBundleId, sourceAppName: sourceAppName)
    }

    private func getImageData(from pasteboard: NSPasteboard) -> Data? {
        // 支援多種圖片格式
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                // 壓縮圖片以節省空間
                if let image = NSImage(data: data),
                   let compressed = compressImage(image, maxSize: 200 * 1024) {
                    return compressed
                }
                return data
            }
        }
        return nil
    }

    private func compressImage(_ image: NSImage, maxSize: Int) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        var compression: Double = 0.8
        var data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])

        // 逐步降低品質直到符合大小限制
        while let d = data, d.count > maxSize, compression > 0.1 {
            compression -= 0.1
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
        }

        return data
    }

    // MARK: - Item Management

    func addItem(content: String, sourceBundleId: String? = nil, sourceAppName: String? = nil) {
        // 移除已存在的相同內容（去重 + 提升）
        items.removeAll { $0.content == content && !$0.isPinned && $0.type != .image }

        var newItem = ClipItem(content: content, sourceBundleId: sourceBundleId, sourceAppName: sourceAppName)
        if TaskManager.shared.isAutoCollectEnabled, let taskId = TaskManager.shared.activeTaskId {
            newItem.taskId = taskId
        }
        items.insert(newItem, at: 0)

        enforceMaxItems()
        saveItems()

        if newItem.taskId != nil {
            TaskManager.shared.syncNewClipItemToActiveCollection(newItem)
        }
    }

    func addImageItem(imageData: Data, sourceBundleId: String? = nil, sourceAppName: String? = nil) {
        var newItem = ClipItem(imageData: imageData, sourceBundleId: sourceBundleId, sourceAppName: sourceAppName)
        if TaskManager.shared.isAutoCollectEnabled, let taskId = TaskManager.shared.activeTaskId {
            newItem.taskId = taskId
        }
        items.insert(newItem, at: 0)

        enforceMaxItems()
        saveItems()

        if newItem.taskId != nil {
            TaskManager.shared.syncNewClipItemToActiveCollection(newItem)
        }

        // 非同步 OCR 辨識
        let itemId = newItem.id
        Task {
            guard let image = NSImage(data: imageData),
                  let ocrText = await OCRManager.shared.recognizeText(from: image) else { return }
            if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                self.items[index].ocrText = ocrText
                self.saveItems()
            }
        }
    }

    private func enforceMaxItems() {
        // 限制未釘選項目數量
        let unpinnedCount = items.filter { !$0.isPinned }.count
        if unpinnedCount > maxItems {
            // 找到最後一個未釘選項目並移除
            if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
                items.remove(at: lastUnpinnedIndex)
            }
        }
    }

    func deleteItem(_ item: ClipItem) {
        TaskManager.shared.removeClipItemFromCollection(item)
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func togglePin(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
            saveItems()
        }
    }

    func clearAll() {
        items.removeAll { !$0.isPinned }
        saveItems()
    }

    func moveToTop(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let movedItem = items.remove(at: index)
        items.insert(movedItem, at: 0)
        saveItems()
    }

    // MARK: - Paste Functionality

    /// 貼上格式
    enum PasteFormat: String, CaseIterable {
        case original = "原始格式"
        case plainText = "純文字"
        case markdown = "Markdown"
        case trimmed = "去頭尾空白"

        var iconName: String {
            switch self {
            case .original: return "doc.richtext"
            case .plainText: return "doc.text"
            case .markdown: return "text.document"
            case .trimmed: return "scissors"
            }
        }
    }

    func pasteItem(_ item: ClipItem, format: PasteFormat = .original) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.type == .image, let imageData = item.imageData {
            pasteboard.setData(imageData, forType: .png)
        } else {
            let content: String
            switch format {
            case .original:
                content = item.content
            case .plainText:
                content = stripFormatting(item.content)
            case .markdown:
                content = convertToMarkdown(item)
            case .trimmed:
                content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            pasteboard.setString(content, forType: .string)
        }

        // 更新 changeCount 避免被自己的監聯器捕捉
        lastChangeCount = pasteboard.changeCount

        // 移到頂部
        moveToTop(item)

        // 先關閉視窗並還原焦點到原本的 App
        PanelManager.shared.hidePanelAndRestoreFocus()

        // 等原本的 App 拿回焦點後再模擬 ⌘V
        simulatePaste()
    }

    /// 去除格式，保留純文字
    private func stripFormatting(_ text: String) -> String {
        // 移除多餘空白、制表符統一化
        let lines = text.components(separatedBy: .newlines)
        return lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 轉換為 Markdown 格式
    private func convertToMarkdown(_ item: ClipItem) -> String {
        switch item.type {
        case .url:
            return "[\(item.content)](\(item.content))"
        case .code:
            return "```\n\(item.content)\n```"
        case .text, .image:
            return item.content
        }
    }

    nonisolated private func simulatePaste() {
        // 延遲讓目標 App 拿回焦點後再送 ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let source = CGEventSource(stateID: .hidSystemState)

            // Key down
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)

            // Key up
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Keyboard Navigation

    func selectNext() {
        let items = filteredItems
        guard !items.isEmpty else { return }

        if let currentId = selectedItemId,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = min(currentIndex + 1, items.count - 1)
            selectedItemId = items[nextIndex].id
        } else {
            selectedItemId = items.first?.id
        }
    }

    func selectPrevious() {
        let items = filteredItems
        guard !items.isEmpty else { return }

        if let currentId = selectedItemId,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectedItemId = items[prevIndex].id
        } else {
            selectedItemId = items.last?.id
        }
    }

    func pasteSelected() {
        guard let selectedId = selectedItemId,
              let item = filteredItems.first(where: { $0.id == selectedId }) else {
            // 如果沒有選中，貼上第一個
            if let firstItem = filteredItems.first {
                pasteItem(firstItem)
            }
            return
        }
        pasteItem(item)
    }

    func pasteItemAtIndex(_ index: Int) {
        let items = filteredItems
        guard index >= 0, index < items.count else { return }
        pasteItem(items[index])
    }

    func indexOfItem(_ item: ClipItem) -> Int? {
        filteredItems.firstIndex(where: { $0.id == item.id })
    }

    func item(withId id: UUID) -> ClipItem? {
        items.first { $0.id == id }
    }

    func setTaskId(_ taskId: UUID, for item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].taskId = taskId
        saveItems()
    }

    func clearTaskId(for item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].taskId = nil
        saveItems()
    }

    // MARK: - Tags

    func addTag(_ tag: String, to item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if !items[index].tags.contains(tag) {
            items[index].tags.append(tag)
            saveItems()
        }
    }

    func removeTag(_ tag: String, from item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].tags.removeAll { $0 == tag }
        saveItems()
    }

    var allTags: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }

    // MARK: - Persistence

    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = decoded
        }
    }

    // MARK: - Exclusion List

    func addExcludedBundleId(_ bundleId: String) {
        excludedBundleIds.insert(bundleId)
    }

    func removeExcludedBundleId(_ bundleId: String) {
        excludedBundleIds.remove(bundleId)
    }

    private func saveExcludedBundleIds() {
        UserDefaults.standard.set(Array(excludedBundleIds), forKey: excludedBundleIdsKey)
    }

    private func loadExcludedBundleIds() {
        if let saved = UserDefaults.standard.array(forKey: excludedBundleIdsKey) as? [String] {
            excludedBundleIds = Set(saved)
        }
    }
}
