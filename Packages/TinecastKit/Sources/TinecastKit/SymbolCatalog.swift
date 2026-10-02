import Foundation

public struct SymbolCatalog: Sendable {
    public struct Section: Sendable, Identifiable {
        public let id: String
        public let title: String
        public let icon: String
        public let symbols: [String]

        public init(id: String, title: String, icon: String, symbols: [String]) {
            self.id = id
            self.title = title
            self.icon = icon
            self.symbols = symbols
        }
    }

    private struct Category: Decodable {
        let key: String
        let icon: String
    }

    private struct Availability: Decodable {
        let symbols: [String: String]
        let yearToRelease: [String: [String: String]]

        private enum CodingKeys: String, CodingKey {
            case symbols
            case yearToRelease = "year_to_release"
        }
    }

    private static let categoryTitles = [
        "whatsnew": "What’s New", "draw": "Draw", "variable": "Variable", "multicolor": "Multicolor",
        "communication": "Communication", "weather": "Weather", "maps": "Maps", "objectsandtools": "Objects & Tools",
        "devices": "Devices", "cameraandphotos": "Camera & Photos", "gaming": "Gaming", "connectivity": "Connectivity",
        "transportation": "Transportation", "automotive": "Automotive", "accessibility": "Accessibility",
        "privacyandsecurity": "Privacy & Security", "human": "Human", "home": "Home", "fitness": "Fitness",
        "nature": "Nature", "editing": "Editing", "textformatting": "Text Formatting", "media": "Media",
        "keyboard": "Keyboard", "commerce": "Commerce", "time": "Time", "health": "Health", "shapes": "Shapes",
        "arrows": "Arrows", "indices": "Indices", "math": "Math",
    ]

    private static let localizationSuffixes: Set<Substring> = [
        "ar", "bn", "el", "gu", "he", "hi", "ja", "km", "kn", "ko", "ml", "mni", "mr", "my",
        "or", "pa", "rtl", "ru", "sat", "si", "ta", "te", "th", "zh",
    ]

    public let sections: [Section]
    private let searchIndex: [(symbol: String, text: String)]

    public init(order: Data, categories: Data, symbolCategories: Data, keywords: Data, restrictions: Data, availability: Data, macOS: OperatingSystemVersion) throws {
        let decoder = PropertyListDecoder()
        let order = try decoder.decode([String].self, from: order)
        let categories = try decoder.decode([Category].self, from: categories)
        let symbolCategories = try decoder.decode([String: [String]].self, from: symbolCategories)
        let keywords = try decoder.decode([String: [String]].self, from: keywords)
        let restricted = try decoder.decode([String: String].self, from: restrictions)
        let availability = try decoder.decode(Availability.self, from: availability)

        let current = [macOS.majorVersion, macOS.minorVersion, macOS.patchVersion]
        let releasedYears = Set(availability.yearToRelease.compactMap { year, platforms -> String? in
            guard let version = platforms["macOS"]?.split(separator: ".").compactMap({ Int($0) }) else { return nil }
            return current.lexicographicallyPrecedes(version) ? nil : year
        })
        let names = Set(order)
        let symbols = order.filter { name in
            guard restricted[name] == nil, let year = availability.symbols[name], releasedYears.contains(year) else { return false }
            let parts = name.split(separator: ".")
            guard let suffix = parts.last, parts.count > 1, Self.localizationSuffixes.contains(suffix) else { return true }
            return !names.contains(parts.dropLast().joined(separator: "."))
        }

        let categorized = categories.filter { $0.key != "all" }.map { category in
            Section(
                id: category.key,
                title: Self.categoryTitles[category.key] ?? category.key.capitalized,
                icon: category.icon,
                symbols: symbols.filter { symbolCategories[$0]?.contains(category.key) == true }
            )
        }
        let other = Section(id: "other", title: "Other", icon: "ellipsis.circle", symbols: symbols.filter { symbolCategories[$0] == nil })
        self.sections = (categorized + [other]).filter { !$0.symbols.isEmpty }
        searchIndex = symbols.map { symbol in
            (symbol, ([symbol, symbol.replacing(".", with: " ")] + (keywords[symbol] ?? [])).joined(separator: "\n").lowercased())
        }
    }

    public func search(_ query: String) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return searchIndex.filter { $0.text.contains(needle) }.map(\.symbol)
    }
}
