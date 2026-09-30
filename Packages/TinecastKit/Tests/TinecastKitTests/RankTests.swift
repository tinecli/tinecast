import Foundation
import Testing
import TinecastKit

@Test func rankFiltersTitlesIgnoringCaseAndDiacriticsInOrder() {
    let items = ["Café", "Calendar", "Safari", "Maps"].map {
        Item(id: $0, title: $0, icon: .symbol("app"), action: .open(URL(filePath: "/Applications/\($0).app")))
    }

    #expect(rank(items, query: "").isEmpty)
    #expect(rank(items, query: "CAFE").map(\.title) == ["Café"])
    #expect(rank(items, query: "a").map(\.title) == ["Café", "Calendar", "Safari", "Maps"])
    #expect(rank(items, query: "ar").map(\.title) == ["Calendar", "Safari"])
}
