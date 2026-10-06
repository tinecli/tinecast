import Foundation

public enum ItemAction: Hashable, Sendable {
    case open, run, copyAnswer, copyDecimal, copyExpression, showInFinder, openWith, copyPath, quitApp, moveToTrash, editInSettings, setAlias, hideFromSearch

    public static func groups(for item: Item, isRunning: (URL) -> Bool) -> [[ItemAction]] {
        switch item.action {
        case .open(let url) where url.pathExtension == "app":
            [[.open, .showInFinder, .copyPath], isRunning(url) ? [.quitApp] : [], [.setAlias, .hideFromSearch]].filter { !$0.isEmpty }
        case .open:
            [[.open, .showInFinder, .openWith, .copyPath], [.moveToTrash]]
        case .run:
            [[.run], [.editInSettings, .setAlias, .hideFromSearch]]
        case .system:
            [[.run], [.setAlias, .hideFromSearch]]
        case .copy(_, let decimal):
            [decimal == nil ? [.copyAnswer, .copyExpression] : [.copyAnswer, .copyDecimal, .copyExpression]]
        }
    }
}
