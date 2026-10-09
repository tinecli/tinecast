import Foundation

public enum SystemAction: String, CaseIterable, Hashable, Sendable {
    case lockScreen, sleep, sleepDisplays, restart, shutDown, logOut, startScreenSaver
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, toggleMute
    case showDesktop, toggleDarkMode, openTrash, emptyTrash, ejectAllDisks
    case hideOtherApps, showAllApps, quitAllApps

    public var item: Item {
        let (title, symbol, keywords): (String, String, [String]) = switch self {
        case .lockScreen: ("Lock Screen", "lock", ["security"])
        case .sleep: ("Sleep", "powersleep", ["suspend"])
        case .sleepDisplays: ("Sleep Displays", "display", ["monitor", "screen off"])
        case .restart: ("Restart", "restart", ["reboot"])
        case .shutDown: ("Shut Down", "power", ["power off", "turn off"])
        case .logOut: ("Log Out", "rectangle.portrait.and.arrow.right", ["sign out"])
        case .startScreenSaver: ("Start Screen Saver", "sparkles.tv", ["screensaver"])
        case .playPause: ("Play/Pause", "playpause", ["music", "media", "resume", "stop"])
        case .nextTrack: ("Next Track", "forward.end", ["music", "media", "skip"])
        case .previousTrack: ("Previous Track", "backward.end", ["music", "media", "back"])
        case .volumeUp: ("Volume Up", "speaker.plus", ["sound", "louder", "increase"])
        case .volumeDown: ("Volume Down", "speaker.minus", ["sound", "quieter", "decrease"])
        case .toggleMute: ("Toggle Mute", "speaker.slash", ["sound", "silence", "unmute"])
        case .showDesktop: ("Show Desktop", "menubar.dock.rectangle", ["hide windows"])
        case .toggleDarkMode: ("Toggle Dark Mode", "circle.lefthalf.filled", ["appearance", "light mode", "theme"])
        case .openTrash: ("Open Trash", "trash", ["bin"])
        case .emptyTrash: ("Empty Trash", "xmark.bin", ["bin", "delete"])
        case .ejectAllDisks: ("Eject All Disks", "eject", ["unmount", "volumes", "drives"])
        case .hideOtherApps: ("Hide Other Apps", "eye.slash", ["windows"])
        case .showAllApps: ("Show All Apps", "eye", ["unhide", "windows"])
        case .quitAllApps: ("Quit All Apps", "xmark.app", ["close"])
        }
        return Item(id: "system:\(rawValue)", title: title, keywords: keywords, icon: .symbol(symbol), action: .system(self))
    }
}
