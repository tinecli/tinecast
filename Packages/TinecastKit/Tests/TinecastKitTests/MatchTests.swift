import Testing
import TinecastKit

@Test func matchTiersRankStrongestFirst() throws {
    let exact = try #require(matchScore(query: "code", title: "Code", keywords: []))
    let titlePrefix = try #require(matchScore(query: "code", title: "Codeshot", keywords: []))
    let wordStart = try #require(matchScore(query: "code", title: "Visual Studio Code", keywords: []))
    let acronym = try #require(matchScore(query: "vsc", title: "Visual Studio Code", keywords: []))
    let keyword = try #require(matchScore(query: "edit", title: "Xcode", keywords: ["editor", "ide"]))
    let substring = try #require(matchScore(query: "ode", title: "Xcode", keywords: []))

    #expect(exact > titlePrefix)
    #expect(titlePrefix > wordStart)
    #expect(wordStart > acronym)
    #expect(acronym > keyword)
    #expect(keyword > substring)
}

@Test func noMatchReturnsNil() {
    #expect(matchScore(query: "zzz", title: "Safari", keywords: ["browser"]) == nil)
    #expect(matchScore(query: "", title: "Safari", keywords: []) == nil)
    #expect(matchScore(query: "   ", title: "Safari", keywords: []) == nil)
    #expect(matchScore(query: "rows", title: "Safari", keywords: ["browser"]) == nil)
}

@Test func matchingIgnoresCaseAndDiacritics() {
    #expect(matchScore(query: "CAFE", title: "Café", keywords: []) == matchScore(query: "café", title: "Café", keywords: []))
    #expect(matchScore(query: "a", title: "Ämne", keywords: []) == matchScore(query: "ä", title: "Ämne", keywords: []))
    #expect(matchScore(query: "ämne", title: "Amne", keywords: []) == matchScore(query: "amne", title: "Amne", keywords: []))
    #expect(matchScore(query: "  safari ", title: "Safari", keywords: []) == matchScore(query: "safari", title: "Safari", keywords: []))
}

@Test func wordStartCoversSeparatorsAndMultiWordQueries() {
    let wordStart = matchScore(query: "studio", title: "Visual Studio Code", keywords: [])
    #expect(wordStart != nil)
    #expect(matchScore(query: "studio co", title: "Visual Studio Code", keywords: []) == wordStart)
    #expect(matchScore(query: "chat", title: "foo-chat", keywords: []) == wordStart)
    #expect(matchScore(query: "chat", title: "foo_chat", keywords: []) == wordStart)
    #expect(matchScore(query: "chat", title: "foo.chat", keywords: []) == wordStart)
}

@Test func camelCaseTransitionsStartWords() {
    let wordStart = matchScore(query: "studio", title: "Visual Studio Code", keywords: [])
    let acronym = matchScore(query: "vsc", title: "Visual Studio Code", keywords: [])

    #expect(matchScore(query: "code", title: "VSCode", keywords: []) == wordStart)
    #expect(matchScore(query: "tube", title: "MyTube", keywords: []) == wordStart)
    #expect(matchScore(query: "vc", title: "VSCode", keywords: []) == acronym)
    #expect(matchScore(query: "vs", title: "Visual Studio Code", keywords: []) == acronym)
}

@Test func titlePrefixIgnoresWordBoundaries() {
    let titlePrefix = matchScore(query: "code", title: "Codeshot", keywords: [])
    #expect(matchScore(query: "vsco", title: "VSCode", keywords: []) == titlePrefix)
}
