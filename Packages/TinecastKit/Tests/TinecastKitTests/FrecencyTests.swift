import Foundation
import Testing
import TinecastKit

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
private let day: TimeInterval = 24 * 60 * 60

@Test func learnedQueriesBenefitTheirPrefixes() {
    var frecency = Frecency()
    frecency.record(query: "goog", itemID: "chrome", at: start)

    #expect(frecency.score(query: "g", itemID: "chrome", now: start) == 1)
    #expect(frecency.score(query: "goog", itemID: "chrome", now: start) == 1)
    #expect(frecency.score(query: "googl", itemID: "chrome", now: start) == 0)
    #expect(frecency.score(query: "c", itemID: "chrome", now: start) == 0)
    #expect(frecency.score(query: "g", itemID: "garageband", now: start) == 0)
}

@Test func scoreSumsEveryLearnedQueryUnderThePrefix() {
    var frecency = Frecency()
    frecency.record(query: "g", itemID: "chrome", at: start)
    frecency.record(query: "go", itemID: "chrome", at: start)
    frecency.record(query: "goog", itemID: "chrome", at: start)
    frecency.record(query: "goog", itemID: "chrome", at: start)

    #expect(frecency.score(query: "g", itemID: "chrome", now: start) == 4)
    #expect(frecency.score(query: "go", itemID: "chrome", now: start) == 3)
}

@Test func queriesAreNormalised() {
    var frecency = Frecency()
    frecency.record(query: "  Ärlig ", itemID: "app", at: start)

    #expect(frecency.score(query: "ARL", itemID: "app", now: start) == 1)
    #expect(frecency.score(query: "ärl", itemID: "app", now: start) == 1)
}

@Test func usesDecayWithAOneWeekHalfLife() {
    var frecency = Frecency()
    frecency.record(query: "a", itemID: "app", at: start)

    #expect(Frecency.halfLife == 7 * day)
    #expect(frecency.score(query: "a", itemID: "app", now: start + 7 * day) == 0.5)
    #expect(frecency.score(query: "a", itemID: "app", now: start + 14 * day) == 0.25)
}

@Test func recentUseOutweighsOldFrequentUse() {
    var frecency = Frecency()
    for _ in 0..<3 { frecency.record(query: "a", itemID: "old", at: start) }
    frecency.record(query: "a", itemID: "recent", at: start + 14 * day)

    let now = start + 14 * day
    #expect(frecency.score(query: "a", itemID: "old", now: now) == 0.75)
    #expect(frecency.suggestions(limit: 2, now: now) == ["recent", "old"])
}

@Test func suggestionsOrderByOverallFrecencyIncludingEmptyQueries() {
    var frecency = Frecency()
    frecency.record(query: "s", itemID: "safari", at: start)
    frecency.record(query: "", itemID: "mail", at: start)
    frecency.record(query: "m", itemID: "mail", at: start)
    frecency.record(query: "n", itemID: "notes", at: start)
    frecency.record(query: "no", itemID: "notes", at: start)
    frecency.record(query: "not", itemID: "notes", at: start)

    #expect(frecency.suggestions(limit: 10, now: start) == ["notes", "mail", "safari"])
    #expect(frecency.suggestions(limit: 1, now: start) == ["notes"])
    #expect(frecency.score(query: "m", itemID: "mail", now: start) == 1)
}

@Test func capDropsTheWeakestRecordButKeepsTheNewest() {
    var frecency = Frecency()
    frecency.record(query: "weak", itemID: "weak", at: start)
    for index in 0..<Frecency.capacity - 1 {
        frecency.record(query: "q\(index)", itemID: "item\(index)", at: start + day)
        frecency.record(query: "q\(index)", itemID: "item\(index)", at: start + day)
    }
    let now = start + 30 * day
    frecency.record(query: "new", itemID: "new", at: now)

    #expect(frecency.score(query: "weak", itemID: "weak", now: now) == 0)
    #expect(frecency.score(query: "new", itemID: "new", now: now) == 1)
    #expect(frecency.score(query: "q0", itemID: "item0", now: now) > 0)
}

@Test func roundTripsThroughCodable() throws {
    var frecency = Frecency()
    frecency.record(query: "g", itemID: "chrome", at: start)

    let decoded = try JSONDecoder().decode(Frecency.self, from: JSONEncoder().encode(frecency))
    #expect(decoded == frecency)
}
