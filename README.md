# tinecast

A minimal, native macOS launcher. Open apps, find files, do quick math and run
actions from one shortcut. No AI, no telemetry, no accounts. Everything stays on
your Mac.

## What it is

- Swift and SwiftUI only, with one non-activating `NSPanel` (no webview, no
  Electron). It sits on the screen with the mouse, shows over full-screen apps,
  and hands focus back when it closes.
- Liquid Glass throughout, following Apple's Human Interface Guidelines and
  conventions (Settings… ⌘,, Quit tinecast ⌘Q).
- A small core: the providers you would never turn off, and nothing else.
- Local by default. The only network calls are the daily exchange-rate fetch
  from the European Central Bank and the update check (and download) against
  GitHub Releases.

## Features

- **Hotkey.** ⌃Space by default, changeable in Settings. tinecast tells you if
  another app or a system shortcut already uses it.
- **Apps and files.** Apps from the standard folders, with their real icons.
  Files come from Spotlight, up to 5 hits once you type 3 characters, limited to
  the folders you choose. Ranking learns what you pick for each query.
- **History.** Works like a shell: ↑ recalls older queries that start with what
  you typed, and both arrows walk history until you type again. A regular
  expression keeps matching queries out of history and ranking.
- **Calculator.** Math with `+ - * / ^`, `%`, parentheses, `pi`, `sqrt`, `round`,
  `log`, `sin` and more. Currency with ECB reference rates (`100 usd to sek`,
  `14390 SEK + 260 EUR`, `€260`). Units for length, mass, temperature, duration,
  volume, area, speed and storage. A bare amount converts on its own (`6 inch`
  shows cm, `180 cm` shows `5 ft 10 7/8 in`), and inches show in 1/16 fractions
  with the decimal below. ↵ copies the answer.
- **System actions.** Lock Screen, Sleep, Restart, Shut Down, Log Out, Screen
  Saver, media and volume keys, Show Desktop, Toggle Dark Mode, Trash, Eject All
  Disks, Hide Others, Quit All Apps. Destructive ones ask first.
- **Commands.** Your own commands with a name and an SF Symbol. They run
  directly, or in your login shell (`zsh -l -c`) when you turn that on. Each can
  ask for confirmation.
- **Aliases and hiding.** Give any app, action or command an alias, or hide it
  from search.
- **⌘K actions.** A menu of what the selected item can do, such as Show in Finder, Copy Path, Open
  With, Quit, Move to Trash, Edit in Settings, Set Alias and Hide from Search.
- **Settings window** with a search field that finds any setting, app, action or
  command.
- **Compact bar.** Optional: a slim search bar that expands as you type.
- **Welcome window** on first launch to pick the hotkey and turn on Open at
  Login.
- **Self-update.** Checks GitHub Releases daily, verifies the download is signed
  by the same developer, and installs on quit or with Install and Relaunch
  (Settings > General > Updates).

## Install

```sh
brew install --cask tinecli/tap/tinecast
```

Or download the dmg from
[GitHub Releases](https://github.com/tinecli/tinecast/releases/latest) and drag
tinecast to Applications. Released builds are Developer ID signed and notarized,
so they launch normally.

## Requirements

macOS 26+ on Apple Silicon.

## Permissions

None are needed to search, calculate or launch. Some actions ask for one
(Settings > Permissions):

- **Accessibility** for Lock Screen and the media keys, which work by sending
  keystrokes.
- **Automation of System Events** for Restart, Shut Down, Log Out and Toggle
  Dark Mode.
- **Automation of Finder** for Empty Trash and Eject All Disks.

## Configure

Everything lives in `~/Library/Application Support/dev.gustaf.tinecast/`:

- `settings.json`: hotkey, launch at login, compact bar, reopen timeout, file
  search folders and exclusions, history ignore pattern, commands, aliases and
  hidden items. The Settings window edits it, and "Open" under Advanced opens
  the file. It reloads on save. An invalid file keeps the previous settings and
  shows one alert.
- `history.json` and `ranking.json`: your query history and learned ranking.
  Clear them from Settings > History.
- `rates.json`: the cached ECB rates.
- `lifecycle.log`: launch and quit events.

A corrupt history, ranking or rates file is moved aside as `.corrupt`, never
overwritten.

To log main-thread stalls to `diagnostics.log` in the same folder:

```sh
defaults write dev.gustaf.tinecast TinecastDiagnostics -bool YES
```

## Development

Build from source with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
xcodebuild -project Tinecast.xcodeproj -scheme tinecast build
swift test --package-path Packages/TinecastKit   # tests
```

The app target is in `Tinecast/`, and the testable logic is in the
`Packages/TinecastKit` package. Cutting a release:
[docs/RELEASING.md](docs/RELEASING.md).

## License

Licensed under MIT **and** Apache-2.0. See `LICENSE.MIT`, `LICENSE.APACHE`, and
`NOTICE`. The vendored skills in `.claude/skills/` keep their own MIT licenses.
