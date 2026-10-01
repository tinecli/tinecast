import AppKit
import Testing
import TinecastKit

@Test func everyCommandSymbolExistsOnce() {
    let symbols = commandSymbolGroups.flatMap(\.symbols)

    #expect(Set(symbols).count == symbols.count)
    #expect(symbols.contains("terminal"))
    for symbol in symbols {
        #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol) isn't an SF Symbol")
    }
}
