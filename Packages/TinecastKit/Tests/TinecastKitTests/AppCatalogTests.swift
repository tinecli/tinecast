import Foundation
import Testing
import TinecastKit

private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func app(_ title: String) -> Item {
    Item(id: "/Applications/\(title).app", title: title, icon: .symbol("app"), action: .open(URL(filePath: "/Applications/\(title).app")))
}

@Test func alphabeticalIgnoresCaseAndTiesBreakOnID() {
    let twins = ["/b", "/a"].map { Item(id: $0, title: "Twin", icon: .symbol("app"), action: .open(URL(filePath: $0))) }
    let catalog = AppCatalog([(app("zoom"), nil), (app("Arc"), nil), (app("bear"), now), (twins[0], nil), (twins[1], nil)])

    #expect(catalog.alphabetical.map(\.title) == ["Arc", "bear", "Twin", "Twin", "zoom"])
    #expect(catalog.alphabetical.filter { $0.title == "Twin" }.map(\.id) == ["/a", "/b"])
}

@Test func recentsFillAfterLearnedItemsByLastUseWithoutDuplicates() {
    let catalog = AppCatalog([
        (app("Mail"), now - 300),
        (app("Notes"), now - 100),
        (app("Safari"), now - 200),
        (app("Chess"), nil),
    ])
    let recents = catalog.recents(learned: [app("Safari").id], limit: 5) { _ in nil }

    #expect(recents.map(\.title) == ["Safari", "Notes", "Mail"])
}

@Test func recentsCapAtTheLimitWithLearnedFirst() {
    let catalog = AppCatalog((1...6).map { (app("App\($0)"), now - Double($0)) })
    let recents = catalog.recents(learned: [app("App6").id], limit: 5) { _ in nil }

    #expect(recents.map(\.title) == ["App6", "App1", "App2", "App3", "App4"])
}

@Test func recentsResolveLearnedFilesAndDropMissingOnes() {
    let catalog = AppCatalog([(app("Notes"), now)])
    let recents = catalog.recents(learned: ["/gone.txt", "/kept.txt", app("Notes").id], limit: 5) { path in
        path == "/kept.txt" ? Item(id: path, title: "kept.txt", icon: .symbol("doc"), action: .open(URL(filePath: path))) : nil
    }

    #expect(recents.map(\.id) == ["/kept.txt", app("Notes").id])
}

@Test func recentsAreEmptyWithoutLearningOrLastUseDates() {
    let catalog = AppCatalog([(app("Chess"), nil)])

    #expect(catalog.recents(learned: [], limit: 5) { _ in nil }.isEmpty)
}
