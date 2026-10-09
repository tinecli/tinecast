import Foundation

public struct HistoryNavigator: Sendable {
    private var typed = ""
    private var position: Int?

    public var isActive: Bool { position != nil }

    public init() {}

    public mutating func older(typed: String, in history: History) -> String? {
        let entries = history.entries
        let anchor = isActive ? self.typed : typed
        let end = min(position ?? entries.count, entries.count)
        let shown = end < entries.count ? entries[end] : anchor
        let prefix = anchor.localizedLowercase
        guard let index = entries[..<end].lastIndex(where: { $0 != shown && $0.localizedLowercase.hasPrefix(prefix) }) else { return nil }
        self.typed = anchor
        position = index
        return entries[index]
    }

    public mutating func newer(in history: History) -> String? {
        guard let position else { return nil }
        let entries = history.entries
        let current = min(position, entries.count)
        let shown = current < entries.count ? entries[current] : typed
        let prefix = typed.localizedLowercase
        let later = entries[min(current + 1, entries.count)...]
        guard let index = later.firstIndex(where: { $0 != shown && $0.localizedLowercase.hasPrefix(prefix) }) else {
            self.position = entries.count
            return typed
        }
        self.position = index
        return entries[index]
    }

    public mutating func reset() {
        self = HistoryNavigator()
    }
}
