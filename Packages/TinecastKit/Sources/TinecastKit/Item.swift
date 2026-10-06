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

    public var kind: String? {
        switch action {
        case .open(let url): url.pathExtension == "app" ? "Application" : "File"
        case .copy: nil
        case .run: "Command"
        case .system: "System"
        }
    }
}

public enum Icon: Hashable, Sendable {
    case file(URL)
    case symbol(String)
}

public enum Action: Hashable, Sendable {
    case open(URL)
    case copy(String, decimal: String? = nil)
    case run(Command)
    case system(SystemAction)
}
