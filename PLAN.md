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

## v0: the smallest thing worth using daily

- Hotkey (⌘Space, first launch explains unbinding Spotlight's), glass panel on the active screen, Esc and
  click-away close it, launch at login.
- No menu bar item and no Dock icon. The panel has a menu button (settings, quit), ⌘, opens settings and
  ⌘Q quits while the panel is showing.
- Apps with real icons, matching and frecency ranking.
- Empty field shows suggestions, Raycast style: your most frecent items, ready to pick with ↓ and ↵.
  A `compact` config option hides them for a Spotlight-style bar that only expands when you type.
- File search mixed into root results below apps, via `NSMetadataQuery`: a few top hits, only from 3 typed
  characters, ⌘↵ reveals in Finder.
- ↑/↓ prefix query history, persisted locally.
- Config is a JSON file; no settings UI yet. ⌘, and the menu button open it in the default editor, and it
  reloads on save. Keys: hotkey, launch at login, compact mode, reopen timeout, file search folders and exclusions,
  history-ignore pattern.
- Panel behaviour: shows on the current Space, including over full-screen apps; focus goes back to the
  previous app on close; if the hotkey can't be registered (Spotlight still owns it), say so instead of
  failing silently.
- Respects Reduce Motion and Reduce Transparency, and has VoiceOver labels (HIG baseline).
- Unit tests for matching, ranking and history navigation, the logic most likely to regress.
- Signed with Developer ID, built locally. No auto-updater yet.
- A standard Xcode project with a macOS app target (macOS 26+), the way Apple sets up an app. Built from
  scratch, not modelled on tine.

## v1: platform

- **Hotkey.** Global and configurable. Carbon `RegisterEventHotKey`; ⌘Space works once Spotlight's is unbound.
- **Panel.** Non-activating floating panel on the active screen. Shows instantly, closes on Esc or focus loss.
- **Look and feel.** Pure SwiftUI, Liquid Glass, spring animations for show/hide and result changes, SF Symbols.
- **Matching.** Prefix, word-start and acronym (`vsc` finds Visual Studio Code), case and diacritic insensitive.
- **Ranking.** Frecency learned per query prefix: typing `g` and picking Chrome teaches `g` to mean Chrome.
- **History.** Every submitted query is kept in order: persisted, consecutive duplicates collapsed, capped
  (say 500 entries). Arrow keys work like tine's shell integration:
  - ↑/↓ move the selection through results.
  - ↑ on the top row (or with no results) enters history mode, recalling older queries that start with the
    typed text, like zsh's `up-line-or-beginning-search`.
  - In history mode both arrows walk history (↓ towards newer) and never drop back into the list;
    typing leaves history mode. A history-ignore pattern (like tine's `HistoryIgnore`) keeps secrets out.
- **Keyboard.** ↵ runs the primary action, ⌘K opens the action menu, ⌘↵ runs the secondary action
  (reveal in Finder, copy, and so on).
- **Reopen.** Like Raycast's default "pop to root after 90 seconds": reopened within 90 s, the previous query and
  selection are still there; after that, an empty field. The timeout is configurable.
- **Arguments.** Tab moves into an argument field for items that take one (commands).
- **Aliases.** A user alias on any item, for an exact match.
- **Settings.** Hotkey, providers on/off, hidden items, aliases, launch at login (`SMAppService`).

- **Settings location.** Settings, aliases, commands and hidden items live in one `settings.json`. Default is
  Application Support; the user can pick any folder instead (iCloud Drive, Dropbox, a dotfiles repo) and that's
  the whole sync story. Last write wins; the file is watched and reloaded on change. If the folder is in
  iCloud Drive, trigger a download first in case macOS evicted it.
- **History and ranking stay local.** Always in Application Support, never in the chosen folder.
  Settings has Export and Import: one JSON file with history and ranking. Import merges (history appended
  and deduped by time, ranking counts summed) rather than replacing.

## v1: providers

- **Applications.** `NSMetadataQuery` for app bundles; updates live when apps are installed or removed. Real icons.
- **System Settings.** Discovered at runtime, not hardcoded. Every pane is an appex in
  `/System/Library/ExtensionKit/Extensions/` with `EXExtensionPointIdentifier = com.apple.Settings.extension.ui`.
  Its Info.plist gives the display name, the icon (`ISGraphicIconConfiguration`), search terms and deep-link support.
- **System actions.** A curated list with SF Symbols (see below). There's no public API that lists them.
- **Commands.** User-defined shell commands with optional arguments and an optional output view.
- **Calculator.** Inline in root search: math, currency (`14390 SEK + 260 EUR`) and unit conversions
  (`Measurement`/`UnitConverter` from Foundation). ↵ copies the result. Keeps its own history.

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

- **Exchange rates.** Source and refresh (for example the ECB daily feed, which needs no key), and offline behaviour.
- **History and privacy.** Should arguments typed into commands be recorded? A "clear history" button in settings?
- **Distribution.** Developer ID + notarization, updates via Sparkle or manual?
