enum SettingRow: String, CaseIterable {
    case hotkey, openAtLogin, clearSearchAfter, compactBar, version, checkForUpdates, settingsFile
    case accessibility, systemEventsAutomation, finderAutomation, loginItem
    case repairAppIndex
    case addCommand
    case searchIn, exclude
    case autoConvertUnits, inchFractions, decimalPlaces, rateSource, ratesFrom, lastUpdated, refreshRates
    case historyIgnore, searchHistory, suggestions

    var pane: Pane { details.pane }
    var label: String { details.label }
    var keywords: [String] { details.keywords }

    private var details: (pane: Pane, label: String, keywords: [String]) {
        switch self {
        case .hotkey: (.general, "Open tinecast", ["Global Shortcut", "Hotkey", "Keyboard Shortcut"])
        case .openAtLogin: (.general, "Open at Login", ["Launch", "Startup"])
        case .clearSearchAfter: (.general, "Clear Search After", ["Reopen", "Timeout"])
        case .compactBar: (.general, "Compact Bar", ["Slim", "Appearance"])
        case .version: (.general, "Version", ["Updates", "About"])
        case .checkForUpdates: (.general, "Check for Updates", ["Updates", "Download", "Install", "Relaunch"])
        case .settingsFile: (.general, "settings.json", ["Advanced", "Config", "JSON"])
        case .accessibility: (.permissions, "Accessibility", ["Privacy", "Lock Screen", "Media Keys"])
        case .systemEventsAutomation: (.permissions, "Automation: System Events", ["Privacy", "Restart", "Shut Down", "Log Out", "Dark Mode"])
        case .finderAutomation: (.permissions, "Automation: Finder", ["Privacy", "Trash", "Eject"])
        case .loginItem: (.permissions, "Open at Login", ["Login Items"])
        case .repairAppIndex: (.applications, "Repair App Index", ["Spotlight", "Missing Apps", "Reindex", "mdimport"])
        case .addCommand: (.commands, "Add Command…", ["New Command"])
        case .searchIn: (.files, "Search In", ["Folders", "File Search"])
        case .exclude: (.files, "Exclude", ["Folders", "Ignore"])
        case .autoConvertUnits: (.calculator, "Convert Units Automatically", ["Units", "Metric", "Imperial", "Inches", "Centimeters"])
        case .inchFractions: (.calculator, "Inch Fractions", ["Units", "Inches", "Precision", "Feet"])
        case .decimalPlaces: (.calculator, "Decimal Places", ["Precision", "Rounding", "Decimals"])
        case .rateSource: (.calculator, "Source", ["Exchange Rates", "Currency", "European Central Bank"])
        case .ratesFrom: (.calculator, "Rates From", ["Exchange Rates", "Date"])
        case .lastUpdated: (.calculator, "Last Updated", ["Exchange Rates"])
        case .refreshRates: (.calculator, "Refresh Now", ["Exchange Rates", "Download", "Update"])
        case .historyIgnore: (.history, "Ignore Searches Matching", ["Regular Expression", "Privacy"])
        case .searchHistory: (.history, "Search History", ["Clear Search History"])
        case .suggestions: (.history, "Suggestions", ["Reset Suggestions", "Ranking", "Recent"])
        }
    }
}
