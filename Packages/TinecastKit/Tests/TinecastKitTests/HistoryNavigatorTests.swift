import Testing
import TinecastKit

private func history(_ queries: String...) -> History {
    var history = History()
    for query in queries { history.record(query) }
    return history
}

@Test func olderWalksMatchingEntriesAndStopsAtTheOldest() {
    let history = history("git log", "safari", "Git status", "git commit")
    var navigator = HistoryNavigator()

    #expect(!navigator.isActive)
    #expect(navigator.older(typed: "git", in: history) == "git commit")
    #expect(navigator.isActive)
    #expect(navigator.older(typed: "ignored", in: history) == "Git status")
    #expect(navigator.older(typed: "ignored", in: history) == "git log")
    #expect(navigator.older(typed: "ignored", in: history) == nil)
    #expect(navigator.newer(in: history) == "Git status")
}

@Test func emptyTypedTextWalksEveryEntry() {
    let history = history("a", "b")
    var navigator = HistoryNavigator()

    #expect(navigator.older(typed: "", in: history) == "b")
    #expect(navigator.older(typed: "", in: history) == "a")
}

@Test func olderSkipsEntriesEqualToTheShownOne() {
    let history = history("git st", "git co", "git st", "git")
    var navigator = HistoryNavigator()

    #expect(navigator.older(typed: "git", in: history) == "git st")
    #expect(navigator.older(typed: "git", in: history) == "git co")
    #expect(navigator.older(typed: "git", in: history) == "git st")
    #expect(navigator.older(typed: "git", in: history) == nil)
}

@Test func newerWalksBackAndRestoresTypedTextPastTheNewest() {
    let history = history("git log", "safari", "git status")
    var navigator = HistoryNavigator()

    #expect(navigator.older(typed: "git", in: history) == "git status")
    #expect(navigator.older(typed: "git", in: history) == "git log")
    #expect(navigator.newer(in: history) == "git status")
    #expect(navigator.newer(in: history) == "git")
    #expect(navigator.isActive)
    #expect(navigator.newer(in: history) == "git")
    #expect(navigator.older(typed: "ignored", in: history) == "git status")
}

@Test func noMatchStaysInactive() {
    let history = history("safari")
    var navigator = HistoryNavigator()

    #expect(navigator.older(typed: "zzz", in: history) == nil)
    #expect(!navigator.isActive)
    #expect(navigator.newer(in: history) == nil)
    #expect(navigator.older(typed: "saf", in: history) == "safari")
}

@Test func newerWhileInactiveReturnsNil() {
    var navigator = HistoryNavigator()

    #expect(navigator.newer(in: history("safari")) == nil)
}

@Test func resetDeactivatesAndCapturesANewPrefix() {
    let history = history("git log", "safari")
    var navigator = HistoryNavigator()

    #expect(navigator.older(typed: "git", in: history) == "git log")
    navigator.reset()
    #expect(!navigator.isActive)
    #expect(navigator.older(typed: "saf", in: history) == "safari")
}
