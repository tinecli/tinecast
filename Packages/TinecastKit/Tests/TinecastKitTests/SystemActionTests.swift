import Testing
import TinecastKit

@Test func systemActionItemsHaveUniquePrefixedIDsAndTitles() {
    let items = SystemAction.allCases.map(\.item)

    #expect(Set(items.map(\.id)).count == items.count)
    #expect(Set(items.map(\.title)).count == items.count)
    #expect(items.allSatisfy { $0.id.hasPrefix("system:") })
    #expect(SystemAction.lockScreen.item.id == "system:lockScreen")
    #expect(SystemAction.lockScreen.item.action == .system(.lockScreen))
}

@Test func systemActionsAreFoundByKeyword() {
    #expect(rank(SystemAction.allCases.map(\.item), query: "reboot").map(\.title) == ["Restart"])
}
