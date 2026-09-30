import Foundation

public func matchScore(query: String, title: String, keywords: [String]) -> Double? {
    let needle = query
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    guard !needle.isEmpty else { return nil }

    let haystack = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    if haystack == needle { return 1.0 }
    if haystack.hasPrefix(needle) { return 0.9 }

    let titleWords = words(in: title).map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
    if titleWords.indices.contains(where: { titleWords[$0...].joined(separator: " ").hasPrefix(needle) }) { return 0.8 }
    if String(titleWords.compactMap(\.first)).hasPrefix(needle) { return 0.7 }

    let foldedKeywords = keywords.map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
    if foldedKeywords.contains(where: { $0.hasPrefix(needle) }) { return 0.6 }
    if haystack.contains(needle) { return 0.5 }
    return nil
}

private func words(in title: String) -> [String] {
    let characters = Array(title)
    var words: [String] = []
    var current = ""
    for (index, character) in characters.enumerated() {
        if character.isWhitespace || "-_.".contains(character) {
            if !current.isEmpty { words.append(current) }
            current = ""
            continue
        }
        let previous = index > 0 ? characters[index - 1] : nil
        let next = index + 1 < characters.count ? characters[index + 1] : nil
        let startsCamelWord = character.isUppercase
            && (previous?.isLowercase == true || (previous?.isUppercase == true && next?.isLowercase == true))
        if startsCamelWord && !current.isEmpty {
            words.append(current)
            current = ""
        }
        current.append(character)
    }
    if !current.isEmpty { words.append(current) }
    return words
}
