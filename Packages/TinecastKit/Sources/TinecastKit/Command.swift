import Foundation

public struct Command: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var command: String
    public var symbol: String
    public var confirm: Bool

    public init(id: String = UUID().uuidString, name: String, command: String, symbol: String = "terminal", confirm: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.symbol = symbol
        self.confirm = confirm
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? "terminal"
        confirm = try container.decodeIfPresent(Bool.self, forKey: .confirm) ?? false
        guard UUID(uuidString: id) != nil else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "\"\(id)\" isn't a UUID. Run uuidgen in Terminal to make one.")
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: "A command needs a name.")
        }
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .command, in: container, debugDescription: "\"\(name)\" needs a command to run.")
        }
    }

    public var item: Item {
        Item(id: "command:\(id)", title: name, icon: .symbol(symbol), action: .run(self))
    }
}
