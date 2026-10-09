import Foundation
import Testing
import TineCastKit

@Test func recordsTrimmedQueriesNewestLast() {
    var history = History()
    history.record(" git status ")
    history.record("")
    history.record("   ")
    history.record("safari")

    #expect(history.entries == ["git status", "safari"])
}

@Test func collapsesOnlyConsecutiveDuplicates() {
    var history = History()
    for query in ["a", "a", "b", "a ", "a"] { history.record(query) }

    #expect(history.entries == ["a", "b", "a"])
}

@Test func capDropsOldestEntries() {
    var history = History()
    for index in 0..<History.capacity + 3 { history.record("q\(index)") }

    #expect(history.entries.count == 500)
    #expect(history.entries.first == "q3")
    #expect(history.entries.last == "q502")
}

@Test func historyRoundTripsThroughCodable() throws {
    var history = History()
    history.record("safari")

    let decoded = try JSONDecoder().decode(History.self, from: JSONEncoder().encode(history))
    #expect(decoded == history)
}
