import Testing
import Foundation
@testable import ClipStash

@Suite("ClipboardManager Tests")
@MainActor
struct ClipboardManagerTests {

    // MARK: - Helper

    private func makeManager(items: [ClipItem] = []) -> ClipboardManager {
        ClipboardManager(forTesting: items)
    }

    // MARK: - Filtering

    @Test("空搜尋回傳全部，釘選在前")
    func emptySearchReturnsPinnedFirst() {
        let items = [
            ClipItem(content: "unpinned"),
            ClipItem(content: "pinned", isPinned: true),
        ]
        let manager = makeManager(items: items)

        let filtered = manager.filteredItems
        #expect(filtered.count == 2)
        #expect(filtered[0].isPinned == true)
        #expect(filtered[1].isPinned == false)
    }

    @Test("搜尋過濾內容")
    func searchFiltersContent() {
        let items = [
            ClipItem(content: "Hello World"),
            ClipItem(content: "Goodbye"),
        ]
        let manager = makeManager(items: items)
        manager.searchText = "Hello"

        #expect(manager.filteredItems.count == 1)
        #expect(manager.filteredItems[0].content == "Hello World")
    }

    @Test("搜尋不區分大小寫")
    func searchCaseInsensitive() {
        let items = [ClipItem(content: "Hello World")]
        let manager = makeManager(items: items)
        manager.searchText = "hello"

        #expect(manager.filteredItems.count == 1)
    }

    @Test("搜尋可搜標籤")
    func searchMatchesTags() {
        let items = [ClipItem(content: "some text", tags: ["work"])]
        let manager = makeManager(items: items)
        manager.searchText = "work"

        #expect(manager.filteredItems.count == 1)
    }

    @Test("pinnedItems 只回傳釘選項目")
    func pinnedItemsFilter() {
        let items = [
            ClipItem(content: "a", isPinned: true),
            ClipItem(content: "b"),
        ]
        let manager = makeManager(items: items)
        #expect(manager.pinnedItems.count == 1)
        #expect(manager.pinnedItems[0].content == "a")
    }

    @Test("unpinnedItems 只回傳未釘選項目")
    func unpinnedItemsFilter() {
        let items = [
            ClipItem(content: "a", isPinned: true),
            ClipItem(content: "b"),
        ]
        let manager = makeManager(items: items)
        #expect(manager.unpinnedItems.count == 1)
        #expect(manager.unpinnedItems[0].content == "b")
    }

    // MARK: - Item Management

    @Test("addItem 加入到頂部")
    func addItemInsertsAtTop() {
        let manager = makeManager(items: [ClipItem(content: "old")])
        manager.addItem(content: "new")

        #expect(manager.items[0].content == "new")
        #expect(manager.items.count == 2)
    }

    @Test("addItem 去重（相同內容移到頂部）")
    func addItemDeduplicates() {
        let manager = makeManager(items: [
            ClipItem(content: "first"),
            ClipItem(content: "second"),
        ])
        manager.addItem(content: "second")

        #expect(manager.items.count == 2)
        #expect(manager.items[0].content == "second")
    }

    @Test("addItem 不去重釘選項目")
    func addItemDoesNotDeduplicatePinned() {
        let manager = makeManager(items: [
            ClipItem(content: "pinned text", isPinned: true),
        ])
        manager.addItem(content: "pinned text")

        #expect(manager.items.count == 2)
    }

    @Test("deleteItem 刪除項目")
    func deleteItem() {
        let item = ClipItem(content: "to delete")
        let manager = makeManager(items: [item])
        manager.deleteItem(item)

        #expect(manager.items.isEmpty)
    }

    @Test("togglePin 切換釘選狀態")
    func togglePin() {
        let item = ClipItem(content: "test")
        let manager = makeManager(items: [item])

        manager.togglePin(item)
        #expect(manager.items[0].isPinned == true)

        manager.togglePin(manager.items[0])
        #expect(manager.items[0].isPinned == false)
    }

    @Test("clearAll 只清除未釘選")
    func clearAllKeepsPinned() {
        let items = [
            ClipItem(content: "pinned", isPinned: true),
            ClipItem(content: "unpinned1"),
            ClipItem(content: "unpinned2"),
        ]
        let manager = makeManager(items: items)
        manager.clearAll()

        #expect(manager.items.count == 1)
        #expect(manager.items[0].isPinned == true)
    }

    @Test("moveToTop 移動項目到頂部")
    func moveToTop() {
        let items = [
            ClipItem(content: "first"),
            ClipItem(content: "second"),
            ClipItem(content: "third"),
        ]
        let manager = makeManager(items: items)
        manager.moveToTop(items[2])

        #expect(manager.items[0].content == "third")
    }

    @Test("itemCount 回傳正確數量")
    func itemCount() {
        let manager = makeManager(items: [
            ClipItem(content: "a"),
            ClipItem(content: "b"),
        ])
        #expect(manager.itemCount == 2)
    }

    // MARK: - Keyboard Navigation

    @Test("selectNext 選擇下一個")
    func selectNext() {
        let items = [
            ClipItem(content: "a"),
            ClipItem(content: "b"),
            ClipItem(content: "c"),
        ]
        let manager = makeManager(items: items)
        manager.selectedItemId = items[0].id

        manager.selectNext()
        #expect(manager.selectedItemId == items[1].id)
    }

    @Test("selectNext 在最後一個不會超出")
    func selectNextAtEnd() {
        let items = [ClipItem(content: "a"), ClipItem(content: "b")]
        let manager = makeManager(items: items)
        manager.selectedItemId = items[1].id

        manager.selectNext()
        #expect(manager.selectedItemId == items[1].id)
    }

    @Test("selectNext 無選擇時選第一個")
    func selectNextWithNoSelection() {
        let items = [ClipItem(content: "a")]
        let manager = makeManager(items: items)

        manager.selectNext()
        #expect(manager.selectedItemId == items[0].id)
    }

    @Test("selectPrevious 選擇上一個")
    func selectPrevious() {
        let items = [ClipItem(content: "a"), ClipItem(content: "b")]
        let manager = makeManager(items: items)
        manager.selectedItemId = items[1].id

        manager.selectPrevious()
        #expect(manager.selectedItemId == items[0].id)
    }

    @Test("selectPrevious 在第一個不會超出")
    func selectPreviousAtStart() {
        let items = [ClipItem(content: "a"), ClipItem(content: "b")]
        let manager = makeManager(items: items)
        manager.selectedItemId = items[0].id

        manager.selectPrevious()
        #expect(manager.selectedItemId == items[0].id)
    }

    @Test("selectPrevious 無選擇時選最後一個")
    func selectPreviousWithNoSelection() {
        let items = [ClipItem(content: "a"), ClipItem(content: "b")]
        let manager = makeManager(items: items)

        manager.selectPrevious()
        #expect(manager.selectedItemId == items[1].id)
    }

    @Test("空列表 selectNext 不崩潰")
    func selectNextEmpty() {
        let manager = makeManager()
        manager.selectNext()
        #expect(manager.selectedItemId == nil)
    }

    // MARK: - Tags

    @Test("addTag 新增標籤")
    func addTag() {
        let item = ClipItem(content: "test")
        let manager = makeManager(items: [item])
        manager.addTag("work", to: item)

        #expect(manager.items[0].tags == ["work"])
    }

    @Test("addTag 不重複新增")
    func addTagNoDuplicate() {
        let item = ClipItem(content: "test", tags: ["work"])
        let manager = makeManager(items: [item])
        manager.addTag("work", to: item)

        #expect(manager.items[0].tags == ["work"])
    }

    @Test("removeTag 移除標籤")
    func removeTag() {
        let item = ClipItem(content: "test", tags: ["work", "personal"])
        let manager = makeManager(items: [item])
        manager.removeTag("work", from: item)

        #expect(manager.items[0].tags == ["personal"])
    }

    @Test("allTags 回傳所有不重複標籤")
    func allTags() {
        let items = [
            ClipItem(content: "a", tags: ["work", "important"]),
            ClipItem(content: "b", tags: ["work", "personal"]),
        ]
        let manager = makeManager(items: items)
        let tags = manager.allTags

        #expect(tags.count == 3)
        #expect(tags.contains("work"))
        #expect(tags.contains("important"))
        #expect(tags.contains("personal"))
    }

    // MARK: - Regex Search

    @Test("正則搜尋 /pattern/ 語法")
    func regexSearch() {
        let items = [
            ClipItem(content: "error 404 not found"),
            ClipItem(content: "status 200 ok"),
            ClipItem(content: "hello world"),
        ]
        let manager = makeManager(items: items)
        manager.searchText = "/\\d{3}/"

        #expect(manager.filteredItems.count == 2)
    }

    @Test("無效正則不崩潰")
    func invalidRegexDoesNotCrash() {
        let items = [ClipItem(content: "test")]
        let manager = makeManager(items: items)
        manager.searchText = "/[invalid/"

        // 無效正則應回傳全部（regex 建立失敗）
        #expect(manager.filteredItems.count == 1)
    }

    @Test("正則搜尋也搜 OCR 文字")
    func regexSearchIncludesOcrText() {
        let item = ClipItem(imageData: Data([0x00]), ocrText: "Invoice #12345")
        let manager = makeManager(items: [item])
        manager.searchText = "/\\d{5}/"

        #expect(manager.filteredItems.count == 1)
    }

    // MARK: - Type Filter

    @Test("filterType 篩選類型")
    func filterByType() {
        let items = [
            ClipItem(content: "https://example.com"),
            ClipItem(content: "plain text"),
            ClipItem(content: "func hello() {}"),
        ]
        let manager = makeManager(items: items)
        manager.filterType = .url

        #expect(manager.filteredItems.count == 1)
        #expect(manager.filteredItems[0].type == .url)
    }

    @Test("filterType nil 不篩選")
    func filterTypeNilNoFilter() {
        let items = [
            ClipItem(content: "https://example.com"),
            ClipItem(content: "plain text"),
        ]
        let manager = makeManager(items: items)
        manager.filterType = nil

        #expect(manager.filteredItems.count == 2)
    }

    // MARK: - Source Filter

    @Test("filterSource 篩選來源")
    func filterBySource() {
        let items = [
            ClipItem(content: "https://github.com/user/repo"),
            ClipItem(content: "https://myteam.slack.com/archives/C123"),
            ClipItem(content: "plain text"),
        ]
        let manager = makeManager(items: items)
        manager.filterSource = .github

        #expect(manager.filteredItems.count == 1)
        #expect(manager.filteredItems[0].detectedSource == .github)
    }

    // MARK: - Tag Filter

    @Test("filterTag 篩選標籤")
    func filterByTag() {
        let items = [
            ClipItem(content: "a", tags: ["work"]),
            ClipItem(content: "b", tags: ["personal"]),
            ClipItem(content: "c"),
        ]
        let manager = makeManager(items: items)
        manager.filterTag = "work"

        #expect(manager.filteredItems.count == 1)
        #expect(manager.filteredItems[0].content == "a")
    }

    // MARK: - Combined Filters

    @Test("多重篩選組合")
    func combinedFilters() {
        let items = [
            ClipItem(content: "https://github.com/repo", tags: ["work"]),
            ClipItem(content: "https://github.com/other"),
            ClipItem(content: "plain text", tags: ["work"]),
        ]
        let manager = makeManager(items: items)
        manager.filterType = .url
        manager.filterTag = "work"

        #expect(manager.filteredItems.count == 1)
        #expect(manager.filteredItems[0].content == "https://github.com/repo")
    }

    @Test("hasActiveFilters 反映篩選狀態")
    func hasActiveFilters() {
        let manager = makeManager()
        #expect(manager.hasActiveFilters == false)

        manager.filterType = .text
        #expect(manager.hasActiveFilters == true)

        manager.clearFilters()
        #expect(manager.hasActiveFilters == false)
    }

    // MARK: - OCR Text Search

    @Test("一般搜尋包含 OCR 文字")
    func searchIncludesOcrText() {
        let item = ClipItem(imageData: Data([0x00]), ocrText: "Hello from image")
        let manager = makeManager(items: [item])
        manager.searchText = "Hello"

        #expect(manager.filteredItems.count == 1)
    }

    @Test("OCR 文字不符時不回傳")
    func searchExcludesNonMatchingOcr() {
        let item = ClipItem(imageData: Data([0x00]), ocrText: "Hello from image")
        let manager = makeManager(items: [item])
        manager.searchText = "Goodbye"

        #expect(manager.filteredItems.count == 0)
    }

    // MARK: - Index

    @Test("indexOfItem 回傳正確 index")
    func indexOfItem() {
        let items = [
            ClipItem(content: "a"),
            ClipItem(content: "b"),
        ]
        let manager = makeManager(items: items)
        #expect(manager.indexOfItem(items[1]) == 1)
    }

    @Test("indexOfItem 不存在回傳 nil")
    func indexOfItemNotFound() {
        let manager = makeManager(items: [ClipItem(content: "a")])
        let missing = ClipItem(content: "b")
        #expect(manager.indexOfItem(missing) == nil)
    }
}
