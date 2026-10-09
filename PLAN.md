# Plan

## Requirements

- **Truly macOS native.** Swift only, no web views, no Electron, no cross-platform layers.
- **HIG grounded.** Every UI decision cites the Apple Human Interface Guidelines: spacing, type, materials, motion, focus.
- **Glass.** Liquid Glass materials throughout, as the system uses them.
- **Apple conventions by default.** Where Apple has a standard (wording like "Settings…" and "Quit tinecast",
  shortcuts like ⌘, and ⌘Q, standard controls and behaviours), use it instead of inventing one.

## Design guidance

Project skills in `.claude/skills/` (vendored, MIT, licence kept in each folder):

- **From [YordiLorenzo/liquid-glass-skills](https://github.com/YordiLorenzo/liquid-glass-skills):** `liquid-glass`
  (the material, AppKit and Tahoe window chrome, accessibility), `liquid-glass-motion` (morphing, transitions,
  Reduce Motion, profiling) and `apple-motion-feel` (spring values, interruptibility). Every rule has a
  confidence tag; check `[single]` ones against Apple's docs.
- **From [rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills):**
  `sf-symbols`, `typography`, `ui-review-tahoe` (macOS HIG review) and `appkit-swiftui-bridge` (the `NSPanel` side).
- **Gap:** no skill covers a non-activating, Spotlight-style panel; that part is AppKit done by hand.
- **Source of truth:** Apple's HIG and API docs win over any skill.

## Principle

The core is the platform plus the providers you would never turn off. Everything else can wait,
and later becomes an extension. Built-in providers use the same provider shape extensions will,
so the shape gets proven before any extension exists.

Every item is `{ title, icon, keywords, action }`. Actions are a small closed set: open an app,
open a URL, run a process, run AppleScript, call a system API.

## v0: built

**Panel and platform**
- ⌃Space by default, configurable via `hotkey`. An alert appears only when a newly chosen combination can't be registered.
- Non-activating glass panel on the screen with the mouse. It shows on every Space, including over full-screen
  apps, and focus returns to the previous app when it closes. Esc and click-away close it.
- One Liquid Glass surface. The panel's colours (selection, search text, icon) are fixed from the system
  light/dark setting, because glass would otherwise re-tint them against the backdrop.
- Motion: show/hide materializes in 0.12 s. ↵/⌘↵ hide instantly, then open. Nothing animates while typing.
  In compact mode only the bar↔panel change animates.
- No Dock icon and no menu bar item. Panel controls:
  - The expanded panel has a round menu button (Settings… ⌘,, Quit tinecast ⌘Q).
  - An action pill shows the selected item's actions and shortcuts (Open ↵, Show in Finder ⌘↵, Copy Answer ↵).
- Reopen within `reopenTimeout` (90 s) keeps the query and selection.

**Search**
- Apps from the standard folders only, deduped by bundle ID, with nested apps excluded. Real icons, cached.
- Matching tiers: exact, prefix, word-start, acronym, keyword, substring. Case and diacritic insensitive.
- Frecency is learned per query prefix (7-day half-life).
- File search via `NSMetadataQuery`: up to 5 hits below apps, from 3 characters, debounced 100 ms. Stale rows
  are filtered out and the configured folders/exclusions are honoured.
- Empty field, non-compact: always fully expanded with **Recent** and **Applications** (A to Z) sections.
  - Recent lists learned items first, then macOS last-used dates.
- While typing, results are grouped under **Applications** / **Files**. "No Results" shows only once file search
  has answered. In compact mode it never expands the bar.
- History works like tine's shell integration:
  - ↑ on the top row recalls older queries with the typed prefix.
  - Both arrows walk history until you type.
  - `historyIgnore` keeps matching queries out of history and ranking.

**Calculator**
- Hand-written parser:
  - operators `+ - * / × ÷ ^`, `%`, parentheses
  - constants and functions (`sqrt`, `round`, `log`, `sin`, …)
  - locale-aware decimal and grouping separators
- Currency: `14390 SEK + 260 EUR`, `100 usd to sek`, `€260`. Sums convert to the first currency, a lone amount
  to the local currency.
- Units via Foundation `Measurement`: length, mass, temperature, duration, volume, area, speed, storage.
- Conversion card: value → result with name tags, plus the ECB rate and its date. ↵ copies the answer.
- Number formatting uses `NumberFormatter`, which honours the user's custom number symbols (`FormatStyle`
  doesn't).
- Rates:
  - ECB reference rates (`data-api.ecb.europa.eu`, no key), cached in `rates.json`.
  - Stale once a weekday 16:15 Berlin time has passed after the stored rate date.
  - Fetched at launch and on use when stale, one in flight, retried hourly on failure.

**Storage and settings**
- `~/Library/Application Support/dev.gustaf.tinecast/` holds `settings.json`, `history.json`, `ranking.json`
  and `rates.json`.
- A corrupt file is moved aside as `.corrupt`, never overwritten. Write failures are logged.
- `settings.json` keys: `hotkey`, `launchAtLogin`, `compact`, `reopenTimeout`, `fileSearch`, `historyIgnore`.
  - It's watched and reloads on save.
  - An invalid file keeps the previous settings and shows one alert.
  - Edited through the Settings window (v1); "Open settings.json" there opens the file for advanced edits.

**Project**
- Swift only:
  - xcodegen `project.yml` with synced folders
  - an app target (macOS 26+, Swift 6, main-actor default isolation)
  - a `TineCastKit` logic package with Swift Testing tests

### Left for v0

- A Release build signed with Developer ID, installed in `/Applications`. Launch at login should only be turned
  on for that build. Notarize when sharing.
- Confirm on screen:
  - `historyIgnore`
  - launch at login

## v1: platform

- **Keyboard.** ⌘K opens an action menu for the selected item.
- **Arguments.** Tab moves into an argument field for items that take one (commands).
- **Aliases.** A user alias on any item, for an exact match.
- **Settings window.** Hotkey, providers on/off, hidden items, aliases, launch at login.
- **Settings location.** The user can move `settings.json` to any folder (iCloud Drive, Dropbox, a dotfiles repo),
  and that's the whole sync story. Last write wins. If the folder is in iCloud Drive, trigger a download first
  in case macOS evicted it.
- **History and ranking stay local**, never in the chosen folder. Settings gets Export and Import of one JSON
  file with history and ranking. Import merges (history appended and deduped, ranking counts summed).
- **Icons.** Preload app icons into the cache at launch.

## v1: providers

- **System Settings.** Discovered at runtime, not hardcoded. Every pane is an appex in
  `/System/Library/ExtensionKit/Extensions/` with `EXExtensionPointIdentifier = com.apple.Settings.extension.ui`.
  Its Info.plist gives the display name, the icon (`ISGraphicIconConfiguration`), search terms and deep-link support.
- **System actions.** A curated list with SF Symbols (see below). There's no public API that lists them.
- **Commands.** User-defined shell commands with optional arguments and an optional output view.
- **Calculator extras.**
  - `kr` (and Swedish names) as SEK
  - `x` as multiply
  - implicit multiplication (`2pi`)
  - modulo
  - its own history

## v1.x: next providers

- **Quicklinks.** URL templates with `{argument}`.
- **Apple Shortcuts.** From `shortcuts list`, run with `shortcuts run`. They also fill any gap in system actions:
  anything Apple exposes as an App Intent can be wrapped in a Shortcut and shows up here.

## System action catalog

Launchers hardcode these, typically about 30. How each one is run:

| Action | Mechanism |
|---|---|
| Lock screen | Post ⌃⌘Q with `CGEvent` |
| Sleep, sleep displays | `pmset sleepnow`, `pmset displaysleepnow` |
| Restart, shut down, log out | AppleScript to System Events |
| Screen saver | Open `ScreenSaverEngine.app` |
| Play/pause, next, previous | Post media key events |
| Volume, mute | CoreAudio on the default output device |
| Show desktop | Launch Mission Control with argument `1` (LaunchServices only, a direct exec is killed) |
| Toggle dark mode | AppleScript to System Events appearance preferences |
| Open trash, empty trash | Finder / AppleScript to Finder |
| Eject all disks | AppleScript to Finder |
| Toggle hidden files | `defaults write com.apple.finder AppleShowAllFiles`, then restart Finder |
| Hide others, unhide all, quit all | `NSRunningApplication` |
| Toggle Bluetooth | Private `IOBluetooth` symbols via `dlsym` |
| Toggle Stage Manager | `defaults` on `com.apple.WindowManager` |
| Dismiss notifications | Accessibility API on Notification Center |

Destructive actions (restart, shut down, log out, empty trash, quit all) ask for confirmation.

## Later: extensions

Parked, but the design leaves room for Raycast compatibility as an optional layer, so the top of the
Raycast store (Kill Process, Color Picker, Google Chrome, Google Translate, Spotify Player, Visual Studio Code,
Linear, Slack, Brew, Notion) can run later.

Layers, bottom up:

1. **Render protocol.** A `Codable` node tree that Swift draws natively. Its vocabulary mirrors Raycast's
   components and prop names (`List`, `List.Item`, `List.Section`, `Detail`, `Form`, `ActionPanel`, `Action`),
   so a Raycast shim is a mapping, not a translation. Built-in providers already produce these values in v1.
2. **Host.** One JavaScriptCore context per running command, plus a Swift bridge: fetch, exec, fs, storage,
   preferences, clipboard, AppleScript, OAuth (Keychain).
3. **APIs on top**, both optional:
   - Our own small JS API that emits the protocol directly.
   - A Raycast shim: React + `react-reconciler` + an `@raycast/api` shim + Node built-in shims, emitting
     the same protocol. This is the expensive part: roughly 200 KB of JS plus a large Swift host.

What the top 10 need from the host: `child_process` (Kill Process, Brew), `fs` and SQLite reads
(Chrome and VS Code history), AppleScript (Chrome, Spotify), and OAuth PKCE (Linear, Notion, Slack, Spotify).
Raycast OAuth redirects go to `raycast://` or through raycast.com, so the app has to claim the `raycast`
scheme, which competes with an installed Raycast.

**Build our own shim.** The heavy lifting is React's official `react-reconciler` package; the host config
that commits into a JSON tree is a few hundred lines. The real work is the `@raycast/api` and Node shims,
specified by Raycast's public API docs.

Until then, anything needed from that list can be a small native first-party extension instead
(Kill Process, VS Code recent projects, Chrome tabs are each a few hundred lines of Swift).

## Not doing

AI, telemetry, accounts, cloud sync, Raycast extension compatibility (on purpose: borrow its UX patterns,
not its API), generic JSON-UI frameworks such as json-render.

## Budgets

- Panel visible within one frame of the hotkey.
- Results update within one frame per keystroke.
- Idle memory well under 100 MB.

## Open questions

- **History and privacy.** Should arguments typed into commands be recorded? A "clear history" action?
- **Distribution.** Notarization and updates (Sparkle or manual) once the app is shared.
