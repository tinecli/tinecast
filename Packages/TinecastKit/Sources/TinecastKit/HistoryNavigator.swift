import Foundation

public struct HistoryNavigator: Sendable {
    public private(set) var isActive = false
    private var typed = ""
    private var prefix = ""
    private var position = 0

    public init() {}

    public mutating func older(typed: String, in history: History) -> String? {
        let entries = history.entries
        if !isActive {
            self.typed = typed
            prefix = typed.localizedLowercase
            position = entries.count
            isActive = true
        }
        let end = min(position, entries.count)
        let shown = end < entries.count ? entries[end] : typed
        guard let index = entries[..<end].lastIndex(where: { $0 != shown && $0.localizedLowercase.hasPrefix(prefix) }) else { return nil }
        position = index
        return entries[index]
    }

    public mutating func newer(in history: History) -> String? {
        guard isActive else { return nil }
        let entries = history.entries
        let current = min(position, entries.count)
        let shown = current < entries.count ? entries[current] : typed
        let later = entries[min(current + 1, entries.count)...]
        guard let index = later.firstIndex(where: { $0 != shown && $0.localizedLowercase.hasPrefix(prefix) }) else {
            position = entries.count
            return typed
        }
        position = index
        return entries[index]
    }

    public mutating func reset() {
        isActive = false
        typed = ""
        prefix = ""
        position = 0
    }
}
