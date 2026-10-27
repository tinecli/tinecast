import Foundation
import Testing
import TineCastKit

private let safari = Item(id: "/Applications/Safari.app", title: "Safari", icon: .symbol("safari"), action: .open(URL(filePath: "/Applications/Safari.app")))

@Test func runningApplicationsOfferWindowsAndQuit() {
    #expect(ItemAction.groups(for: safari) { _ in true } == [[.open, .showInFinder, .copyPath], [.showWindows], [.quitApp], [.setAlias, .hideFromSearch]])
}

@Test func applicationsThatArentRunningOfferNoWindowsOrQuit() {
    #expect(ItemAction.groups(for: safari) { _ in false } == [[.open, .showInFinder, .copyPath], [.setAlias, .hideFromSearch]])
}

@Test func filesOfferOpenWithAndTrash() {
    let file = Item(id: "/tmp/notes.txt", title: "notes.txt", icon: .symbol("doc"), action: .open(URL(filePath: "/tmp/notes.txt")))

    #expect(ItemAction.groups(for: file) { _ in true } == [[.open, .showInFinder, .openWith, .copyPath], [.moveToTrash]])
}

@Test func commandsCanBeEditedInSettings() {
    let command = Command(name: "Deploy", command: "make deploy").item

    #expect(ItemAction.groups(for: command) { _ in true } == [[.run], [.editInSettings, .setAlias, .hideFromSearch]])
}

@Test func systemActionsCanBeAliasedAndHidden() {
    #expect(ItemAction.groups(for: SystemAction.sleep.item) { _ in true } == [[.run], [.setAlias, .hideFromSearch]])
}

@Test func calculationsOfferBothCopies() {
    let answer = Item(id: "calculator", title: "4", subtitle: "2+2", icon: .symbol("equal.circle"), action: .copy("4"))

    #expect(ItemAction.groups(for: answer) { _ in true } == [[.copyAnswer, .copyExpression]])
}

@Test func fractionalInchesOfferCopyDecimal() {
    let answer = Item(id: "calculator", title: "1/2 in", subtitle: "12.7 mm in in", icon: .symbol("equal.circle"), action: .copy("1/2 in", decimal: "0.5"))

    #expect(ItemAction.groups(for: answer) { _ in true } == [[.copyAnswer, .copyDecimal, .copyExpression]])
}

@Test func windowsOnlyOpen() {
    let window = Item(id: "window:42:0", title: "Start Page", icon: .symbol("macwindow"), action: .window(pid: 42, index: 0, title: "Start Page"))

    #expect(window.kind == "Window")
    #expect(ItemAction.groups(for: window) { _ in true } == [[.open]])
}
