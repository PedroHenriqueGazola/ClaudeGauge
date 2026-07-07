# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

ClaudeGauge is a macOS menu-bar app (Swift Package Manager, SwiftUI + AppKit) that shows your Claude usage limits (5h session + weekly). UI strings and code comments are in Portuguese.

## Commands

```bash
swift build                 # debug build (what CI runs)
swift build -c release      # release build
swift run                   # fast dev run — see caveat below
./scripts/make-app.sh       # build release binary + assemble & codesign ClaudeGauge.app
./scripts/make-icon.sh      # regenerate Resources/AppIcon.icns
```

There is **no test target** — `swift test` does nothing.

`swift run` runs the raw binary with no bundle identifier, so **notifications and run-at-login are disabled** (both gate on `Bundle.main.bundleIdentifier != nil`). To exercise those, build the `.app` via `make-app.sh` and `open ClaudeGauge.app`.

Releases are published by pushing a `v*` git tag (`.github/workflows/release.yml`), which runs `make-app.sh` with `APP_VERSION` set to the tag and uploads a zipped `.app`.

## Architecture

Single executable target `Sources/ClaudeGauge`. Runs as an `.accessory` app (no dock icon).

**Refresh loop.** `ClaudeGaugeApp` installs `AppDelegate`, which owns the `NSStatusItem` + `NSPopover` + settings `NSWindow`. `UsageModel` (`@MainActor @Observable` singleton) is the core: a timer + wake-from-sleep observer call `refresh()`, which does `AuthProvider.currentAuth()` → `UsageAPIClient.fetchUsage()` → publishes a `UsageSnapshot`. `AppDelegate.observeSnapshot()` uses `withObservationTracking` to re-render the menu-bar image whenever the snapshot changes. `refresh()` self-throttles via `nextAllowedFetch` (30s min, or `Retry-After`/300s after a 429); pass `force: true` to bypass.

**Auth resolution** (`AuthProvider.resolve`, in priority order):
1. The app's **own** OAuth tokens from the Keychain (`TokenStore`, service `com.pedrogazola.claudegauge.oauth`), auto-refreshed when expired.
2. Fallback to **Claude Code's** credentials via `CredentialsReader`: env var `CLAUDE_CODE_OAUTH_TOKEN`, else `~/.claude/.credentials.json` (path overridable with `CLAUDE_CONFIG_DIR`). It deliberately does **not** read the CLI's Keychain item — cross-app Keychain access triggers a macOS password prompt on every CLI token refresh.

**OAuth** (`OAuthService`, driven by `LoginModel`) is a PKCE flow with a manual paste-the-code step (no loopback server). Two constraints are load-bearing and documented inline: it reuses Claude Code's public `clientID` (the only client the usage endpoint accepts), and sends `User-Agent: axios/1.13.6` to the token endpoint to dodge a bogus 429.

**Usage API** (`UsageAPIClient`): primary is `GET /api/oauth/usage`; on 404/410 it falls back to `POST /v1/messages` and reads usage from `anthropic-ratelimit-unified-*` headers (this fallback only yields the 5h + 7d windows, not per-model). Sends `User-Agent: claude-code/2.1.5` and the `oauth-2025-04-20` beta header. **These endpoints are unofficial/internal Anthropic APIs and may change without notice.**

**Rendering.** `MenuBarImageRenderer` draws a custom colored `NSImage` (non-template, so its progress bars keep color), adapting text to light/dark. `PopoverView`/`SettingsView`/`UsageRow` are SwiftUI; `Theme.swift` defines `Palette` + hex-init helpers. `NotificationCenterService` fires once per window per 75/90/95% threshold (configurable in `UserDefaults`), resetting when a window's usage drops.

**Claude Code hook integration.** The app registers a `claudegauge://` URL scheme (`CFBundleURLTypes` in `make-app.sh`; handled in `AppDelegate` via `NSAppleEventManager` + `ClaudeHookURL.parse`). `scripts/claude-notify.sh`, wired into `~/.claude/settings.json` as `Stop`/`Notification` hooks, reads the hook's stdin JSON (`cwd` via `plutil`, no external deps) and calls `open claudegauge://notify?event=finished|attention&project=…`. The app then fires a system notification via `UsageModel.notifyClaudeHook` → `NotificationCenterService.notify(_:)`. Only works from the built `.app` (the scheme must be registered in Launch Services), same bundle-only constraint as notifications.

**Transcript watcher (hook-free fallback).** Managed orgs can set `allowManagedHooksOnly: true` (delivered via remote/managed settings, e.g. `~/.claude/remote-settings.json`), which makes Claude Code silently ignore every user hook — so the URL-scheme path above never fires. `TranscriptWatcher` is the fallback that needs no hooks: it uses FSEvents to watch `~/.claude/projects/**/*.jsonl` (dir overridable via `CLAUDE_CONFIG_DIR`), reads new lines incrementally by byte offset (seeking to EOF on start so history isn't replayed), and fires `.finished` when it sees an `assistant` line whose `message.stop_reason` is `end_turn`/`stop_sequence` (skipping `isSidechain` subagents). Started from `UsageModel.start()`, gated by the `notifyOnTurnEnd` UserDefault (default on). It detects only turn-end, **not** attention/permission (the transcript doesn't record those reliably). FSEvents gotcha: the stream MUST pass `kFSEventStreamCreateFlagUseCFTypes`, otherwise the callback's `paths` is a `char **` and casting it to `NSArray` segfaults.

Set `CLAUDEGAUGE_DEBUG=1` to log parsed snapshot percentages, received hook URLs, and notification-scheduling results to stderr.

## Code signing (dev)

`make-app.sh` signs ad-hoc (`-`) by default, which changes the app identity every rebuild and makes macOS re-prompt for Keychain access. To avoid this, create a local self-signed code-signing certificate named `ClaudeGauge Dev` (see README) — the script auto-detects and uses it. Override with the `SIGN_IDENTITY` env var.
