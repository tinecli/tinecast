import Foundation
import Testing
import TineCastKit

private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

private func items(_ titles: String...) -> [Item] {
    titles.map { Item(id: $0, title: $0, icon: .symbol("app"), action: .open(URL(filePath: "/Applications/\($0).app"))) }
}

@Test func rankFiltersIgnoringCaseAndDiacriticsSortingTiesByTitle() {
    let apps = items("Safari", "Maps", "Café", "Calendar")

    #expect(rank(apps, query: "").isEmpty)
    #expect(rank(apps, query: "CAFE").map(\.title) == ["Café"])
    #expect(rank(apps, query: "a").map(\.title) == ["Café", "Calendar", "Maps", "Safari"])
    #expect(rank(apps, query: "ar").map(\.title) == ["Calendar", "Safari"])
}

@Test func rankOrdersByMatchStrength() {
    let apps = items("Xcode", "Visual Studio Code", "Codeshot", "Code")

    #expect(rank(apps, query: "code").map(\.title) == ["Code", "Codeshot", "Visual Studio Code", "Xcode"])
}

@Test func learnedItemWinsItsPrefix() {
    let apps = items("GarageBand", "Google Chrome")
    var frecency = Frecency()

    #expect(rank(apps, query: "g", frecency: frecency, now: now).map(\.title) == ["GarageBand", "Google Chrome"])

    frecency.record(query: "g", itemID: "Google Chrome", at: now)
    #expect(rank(apps, query: "g", frecency: frecency, now: now).map(\.title) == ["Google Chrome", "GarageBand"])
    #expect(rank(apps, query: "ga", frecency: frecency, now: now).map(\.title) == ["GarageBand"])
}

@Test func repeatedLearningOvercomesOneTier() {
    let apps = items("Calendar", "Google Chrome")
    var frecency = Frecency()
    for _ in 0..<3 { frecency.record(query: "c", itemID: "Google Chrome", at: now) }

    #expect(rank(apps, query: "c", frecency: frecency, now: now).map(\.title) == ["Google Chrome", "Calendar"])
}

@Test func strongMatchBeatsWeakMatchWithHeavyHistory() {
    let apps = items("Denotes", "Notes")
    var frecency = Frecency()
    for _ in 0..<50 { frecency.record(query: "notes", itemID: "Denotes", at: now) }

    #expect(rank(apps, query: "notes", frecency: frecency, now: now).map(\.title) == ["Notes", "Denotes"])
}

@Test func historyNeverResurrectsANonMatch() {
    var frecency = Frecency()
    frecency.record(query: "x", itemID: "Safari", at: now)

    #expect(rank(items("Safari"), query: "x", frecency: frecency, now: now).isEmpty)
}

@Test func identicalTitlesTieBreakOnID() {
    let apps = ["b", "a"].map { Item(id: $0, title: "Twin", icon: .symbol("app"), action: .open(URL(filePath: "/\($0)"))) }

    #expect(rank(apps, query: "twin").map(\.id) == ["a", "b"])
}

@Test func exactAliasRanksFirstAboveLearnedExactTitles() {
    let apps = items("Terminal", "Tower")
    var frecency = Frecency()
    for _ in 0..<50 { frecency.record(query: "term", itemID: "Terminal", at: now) }
    let aliases = ["Tower": " TERM "]

    #expect(rank(apps, query: "term", frecency: frecency, aliases: aliases, now: now).map(\.title) == ["Tower", "Terminal"])
    #expect(rank(items("term", "Tower"), query: "term", aliases: aliases).map(\.title) == ["Tower", "term"])
}

@Test func aliasPrefixScoresLikeATitlePrefix() {
    let apps = items("Codeshot", "Xcode")

    #expect(rank(apps, query: "co", aliases: ["Xcode": "code"]).map(\.title) == ["Codeshot", "Xcode"])
    #expect(matchScore(query: "co", title: "Xcode", keywords: [], alias: "códe") == matchScore(query: "co", title: "Codeshot", keywords: []))
}
