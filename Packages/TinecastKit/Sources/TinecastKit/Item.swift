import Foundation

public struct Item: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let keywords: [String]
    public let icon: Icon
    public let action: Action

    public init(id: String, title: String, subtitle: String? = nil, keywords: [String] = [], icon: Icon, action: Action) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.icon = icon
        self.action = action
    }
}

public enum Icon: Hashable, Sendable {
    case file(URL)
    case symbol(String)
}

public enum Action: Hashable, Sendable {
    case open(URL)
    case copy(String)
}
