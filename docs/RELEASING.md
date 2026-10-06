# Releasing

Tag a version on `main` and push. The `Release` GitHub Action builds the app, packages a Developer ID signed and
notarized dmg, publishes a GitHub Release, and bumps the Homebrew cask in `tinecli/homebrew-tap`:

```sh
git tag v0.1.1 && git push origin v0.1.1
```

The tag sets the version: `CFBundleShortVersionString` is the tag without its `v`, and `CFBundleVersion` is the
workflow's run number. Installed copies find the release through `releases/latest` and update themselves
(Settings > General > Updates).

## Repo secrets

| Secret | Purpose |
| --- | --- |
| `APPLE_CERT_P12` | base64 of the exported "Developer ID Application" cert (`.p12`) |
| `APPLE_CERT_PASSWORD` | password used when exporting that `.p12` |
| `NOTARY_APPLE_ID` | Apple ID email for `notarytool` |
| `NOTARY_PASSWORD` | app-specific password for that Apple ID |
| `TAP_GITHUB_TOKEN` | token with write access to the tap (for the cask bump) |

All five are required: the workflow's preflight step fails the run if any is empty, and the tag must be an
ancestor of `main`. `Casks/tinecast.rb` in [`tinecli/homebrew-tap`](https://github.com/tinecli/homebrew-tap) is
hand-maintained; the workflow only rewrites `version` and `sha256`.

## Building a dmg locally

```sh
scripts/package.sh                       # → dist/Tinecast.app + dist/tinecast-<version>.dmg
```

`package.sh` runs `xcodegen generate`, builds Release for Apple Silicon with `xcodebuild`, and Developer ID signs
with a hardened runtime and `tinecast.entitlements`; set `TINECAST_SIGN_ID=-` for an ad-hoc build. It notarizes
and staples the app and the dmg too when `NOTARY_APPLE_ID` / `NOTARY_TEAM_ID` / `NOTARY_PASSWORD` are set.
