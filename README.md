<div align="center">

<img src="TineCast/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="TineCast app icon">

# TineCast

**One shortcut for apps, files, math and your Mac.**

A minimal, native launcher. No AI, no telemetry, no accounts.

[Download](https://github.com/tinecli/tinecast/releases/latest) · [Install with Homebrew](#install) · Requires macOS 26 on Apple Silicon

</div>

## What it does

Press ⌃Space, type a few letters, press Return. TineCast opens apps, finds files, does math and unit conversions, and runs system actions and your own commands. It learns what you pick for each query, so the right result moves to the top.

TineCast is Swift and SwiftUI only, one panel with Liquid Glass, no webview or Electron. It opens on the screen with the mouse, shows over full-screen apps and hands focus back when it closes. It keeps a small core: the things you would never turn off, and nothing else. The only network calls are the daily exchange rates from the European Central Bank and the update check against GitHub Releases.

| | |
|---|---|
| **Hotkey** | ⌃Space by default, changeable in Settings. TineCast tells you if another app or a system shortcut already uses it. |
| **Apps and files** | Apps from the standard folders with their real icons. Files from Spotlight, up to 5 hits once you type 3 characters, limited to the folders you choose. |
| **Calculator** | `+ - * / ^`, `%`, parentheses, `pi`, `sqrt`, `round`, `log`, `sin` and more. Currency with ECB rates (`100 usd to sek`, `14390 SEK + 260 EUR`). Length, mass, temperature, duration, volume, area, speed and storage. A bare amount converts on its own (`180 cm` shows `5 ft 10 7/8 in`). Return copies the answer. |
| **System actions** | Lock Screen, Sleep, Restart, Shut Down, Log Out, media and volume keys, Toggle Dark Mode, Empty Trash, Eject All Disks, Quit All Apps and more. Destructive ones ask first. |
| **Commands** | Your own commands with a name and an SF Symbol, run directly or in your login shell, with an optional confirmation. |
| **Window switching** | ⇥ on a running app lists its windows, on every Space. |
| **⌘K actions** | What the selected item can do: Show in Finder, Copy Path, Open With, Quit, Move to Trash, Set Alias, Hide from Search. |
| **History** | Works like a shell: ↑ recalls older queries that start with what you typed. A regular expression keeps queries out of history and ranking. |
| **Aliases and hiding** | Give any app, action or command an alias, or hide it from search. |
| **Settings** | A search field that finds any setting, app, action or command. An optional compact bar that expands as you type. |
| **Updates** | Checks GitHub Releases daily, verifies the download is signed by the same developer, and installs on quit. |

## Install

```sh
brew install --cask tinecli/tap/tinecast
```

Or download `tinecast-<version>.dmg` from the [latest release](https://github.com/tinecli/tinecast/releases/latest) and drag TineCast to Applications. TineCast is signed and notarized, and updates itself.

On first launch, the Welcome window lets you pick the hotkey and turn on Open at Login.

## Permissions

Searching, calculating and launching need none. Some actions ask for one (Settings › Permissions):

- **Accessibility** for Lock Screen and the media keys, which work by sending keystrokes.
- **Automation of System Events** for Restart, Shut Down, Log Out and Toggle Dark Mode.
- **Automation of Finder** for Empty Trash and Eject All Disks.

<details>
<summary><b>Where settings live</b></summary>

<br>

Everything is in `~/Library/Application Support/dev.gustaf.tinecast/`:

- `settings.json`: everything the Settings window edits. "Open" under Advanced opens the file, and it reloads on save. An invalid file keeps the previous settings and shows one alert.
- `history.json` and `ranking.json`: your query history and learned ranking. Clear them from Settings › History.
- `rates.json`: the cached ECB rates.
- `lifecycle.log`: launch and quit events.

A corrupt history, ranking or rates file is moved aside as `.corrupt`, never overwritten.

To log main-thread stalls to `diagnostics.log` in the same folder:

```sh
defaults write dev.gustaf.tinecast TinecastDiagnostics -bool YES
```

</details>

<details>
<summary><b>Building from source</b></summary>

<br>

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project TineCast.xcodeproj -scheme tinecast build
swift test --package-path Packages/TineCastKit   # tests
```

The app target is in `TineCast/`, and the testable logic is in the `Packages/TineCastKit` package. Releases are tagged and built by GitHub Actions, see [docs/RELEASING.md](docs/RELEASING.md).

</details>

## License

Licensed under MIT and Apache-2.0, see [LICENSE.MIT](LICENSE.MIT), [LICENSE.APACHE](LICENSE.APACHE) and [NOTICE](NOTICE). The vendored skills in `.claude/skills/` keep their own MIT licenses.
