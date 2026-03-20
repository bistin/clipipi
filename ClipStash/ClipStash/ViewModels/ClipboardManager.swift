import Foundation
import AppKit
import Combine

@MainActor
final class ClipboardManager: ObservableObject, Sendable {
    static let shared = ClipboardManager()

    @Published private(set) var items: [ClipItem] = []
    @Published var searchText: String = ""
    @Published var selectedItemId: UUID?

    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 100
    private let userDefaultsKey = "clip_stash_items"

    var filteredItems: [ClipItem] {
        let pinnedItems = items.filter { $0.isPinned }
        let unpinnedItems = items.filter { !$0.isPinned }

        if searchText.isEmpty {
            return pinnedItems + unpinnedItems
        }

        let filteredPinned = pinnedItems.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
        let filteredUnpinned = unpinnedItems.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }

        return filteredPinned + filteredUnpinned
    }

    var pinnedItems: [ClipItem] {
        filteredItems.filter { $0.isPinned }
    }

    var unpinnedItems: [ClipItem] {
        filteredItems.filter { !$0.isPinned }
    }

    var itemCount: Int {
        items.count
    }

    private init() {
        loadItems()
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
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

        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        addItem(content: content)
    }

    // MARK: - Item Management

    func addItem(content: String) {
        // 移除已存在的相同內容（去重 + 提升）
        items.removeAll { $0.content == content && !$0.isPinned }

        let newItem = ClipItem(content: content)
        items.insert(newItem, at: 0)

        // 限制未釘選項目數量
        let unpinnedCount = items.filter { !$0.isPinned }.count
        if unpinnedCount > maxItems {
            // 找到最後一個未釘選項目並移除
            if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
                items.remove(at: lastUnpinnedIndex)
            }
        }

        saveItems()
    }

    func deleteItem(_ item: ClipItem) {
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

    func pasteItem(_ item: ClipItem) {
        // 寫入剪貼簿
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)

        // 更新 changeCount 避免被自己的監聽器捕捉
        lastChangeCount = pasteboard.changeCount

        // 移到頂部
        moveToTop(item)

        // 模擬 ⌘V
        simulatePaste()

        // 關閉視窗
        PanelManager.shared.hidePanel()
    }

    nonisolated private func simulatePaste() {
        // 延遲一點讓視窗先關閉
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
}
