import Foundation
import Testing
import TineCastKit

private func plist(_ value: Any) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
}

private func catalog(
    order: [String] = ["star", "star.fill", "applelogo", "heart", "heart.ar", "sparkle.new", "seal"],
    symbolCategories: [String: [String]] = ["star": ["shapes"], "star.fill": ["shapes"], "heart": ["health", "shapes"], "heart.ar": ["health"], "applelogo": ["objectsandtools"], "sparkle.new": ["shapes"]],
    keywords: [String: [String]] = ["heart": ["love", "noise reduction"]],
    macOS: OperatingSystemVersion = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
) throws -> SymbolCatalog {
    let years = ["star": "2019", "star.fill": "2019", "applelogo": "2020", "heart": "2019", "heart.ar": "2019", "sparkle.new": "2026", "seal": "2025.1"]
    return try SymbolCatalog(
        order: plist(order),
        categories: plist([
            ["key": "all", "icon": "square.grid.2x2"],
            ["key": "health", "icon": "heart"],
            ["key": "objectsandtools", "icon": "folder"],
            ["key": "shapes", "icon": "square.on.circle"],
            ["key": "newthing", "icon": "sparkles"],
        ]),
        symbolCategories: plist(symbolCategories),
        keywords: plist(keywords),
        restrictions: plist(["applelogo": "This symbol may only be used to refer to Apple."]),
        availability: plist([
            "symbols": years,
            "year_to_release": ["2019": ["macOS": "10.15"], "2020": ["macOS": "11.0"], "2025.1": ["macOS": "26.1"], "2026": ["macOS": "27.0"]],
        ]),
        macOS: macOS
    )
}

@Test func sectionsFollowAppleCategoryOrderAndDropAll() throws {
    let sections = try catalog().sections

    #expect(sections.map(\.id) == ["health", "shapes"])
    #expect(sections.map(\.title) == ["Health", "Shapes"])
    #expect(sections.map(\.icon) == ["heart", "square.on.circle"])
}

@Test func symbolsKeepDisplayOrderWithinSections() throws {
    let shapes = try #require(catalog(order: ["heart", "star.fill", "star"]).sections.first { $0.id == "shapes" })

    #expect(shapes.symbols == ["heart", "star.fill", "star"])
}

@Test func excludesRestrictedLocalizedAndUnavailableSymbols() throws {
    let symbols = try catalog().sections.flatMap(\.symbols)

    #expect(!symbols.contains("applelogo"))
    #expect(!symbols.contains("heart.ar"))
    #expect(!symbols.contains("sparkle.new"))
    #expect(!symbols.contains("seal"))
}

@Test func includesSymbolsReleasedUpToTheRunningOS() throws {
    let symbols = try catalog(macOS: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)).sections.flatMap(\.symbols)

    #expect(symbols.contains("sparkle.new"))
    #expect(symbols.contains("seal"))
}

@Test func keepsLocalizationLikeSuffixWithoutBaseSymbol() throws {
    let symbols = try catalog(order: ["heart.ar"]).sections.flatMap(\.symbols)

    #expect(symbols == ["heart.ar"])
}

@Test func uncategorizedSymbolsGoLastInOther() throws {
    let sections = try catalog(macOS: OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)).sections

    #expect(sections.last?.id == "other")
    #expect(sections.last?.symbols == ["seal"])
}

@Test func searchMatchesNamesAndKeywordsInDisplayOrder() throws {
    let symbols = try catalog()

    #expect(symbols.search("noise reduction") == ["heart"])
    #expect(symbols.search("STAR fill") == ["star.fill"])
    #expect(symbols.search("star") == ["star", "star.fill"])
    #expect(symbols.search("  ").isEmpty)
    #expect(symbols.search("applelogo").isEmpty)
}

@Test func malformedDataThrows() {
    #expect(throws: (any Error).self) {
        try SymbolCatalog(order: Data("nope".utf8), categories: Data(), symbolCategories: Data(), keywords: Data(), restrictions: Data(), availability: Data(), macOS: ProcessInfo.processInfo.operatingSystemVersion)
    }
}

@Test func readsTheSystemCatalog() throws {
    let folder = URL(filePath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources")
    let catalog = try SymbolCatalog(
        order: Data(contentsOf: folder.appending(path: "symbol_order.plist")),
        categories: Data(contentsOf: folder.appending(path: "categories.plist")),
        symbolCategories: Data(contentsOf: folder.appending(path: "symbol_categories.plist")),
        keywords: Data(contentsOf: folder.appending(path: "symbol_search.plist")),
        restrictions: Data(contentsOf: folder.appending(path: "symbol_restrictions.strings")),
        availability: Data(contentsOf: folder.appending(path: "name_availability.plist")),
        macOS: ProcessInfo.processInfo.operatingSystemVersion
    )
    let symbols = Set(catalog.sections.flatMap(\.symbols))

    #expect(symbols.contains("apple.terminal"))
    #expect(!symbols.contains("apple.logo"))
    #expect(catalog.search("noise reduction").contains("circle.bottomrighthalf.pattern.checkered"))
    #expect(catalog.sections.map(\.title).contains("Objects & Tools"))
}
