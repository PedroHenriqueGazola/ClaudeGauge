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

**Rendering.** `MenuBarImageRenderer` draws a custom colored `NSImage` (non-template, so its progress bars keep color), adapting text to light/dark, and appends the 5h window's reset countdown after its bar. `PopoverView`/`SettingsView`/`UsageRow` are SwiftUI; `Theme.swift` defines `Palette` + hex-init helpers. `NotificationCenterService` fires once per window per 75/90/95% threshold (configurable in `UserDefaults`), resetting when a window's usage drops.

**Claude Code hook integration.** The app registers a `claudegauge://` URL scheme (`CFBundleURLTypes` in `make-app.sh`; handled in `AppDelegate` via `NSAppleEventManager` + `ClaudeHookURL.parse`). `scripts/claude-notify.sh` is bundled into `Contents/Resources` (by `make-app.sh`); the **"precisa de você"** toggle in `SettingsView` calls `ClaudeHookInstaller`, which writes/removes a `Notification` hook in `~/.claude/settings.json` pointing at the bundled script (merging — it only touches the group whose command contains `claude-notify.sh`, preserving other settings/hooks; re-synced on launch via `UsageModel.syncAttentionHook` so the path survives app moves). The script reads the hook's stdin JSON (`cwd` + `message` + `transcript_path` via `plutil`, no external deps) and calls `open claudegauge://notify?event=attention&project=…&detail=…&transcript=…`. `UsageModel.enrich` then replaces the generic `message` with what Claude actually wants — `ClaudeTranscript.pendingToolSummary` reads the tail of the transcript and summarizes the last `tool_use` (e.g. `Bash: npm run deploy`). The app fires a system notification via `UsageModel.notifyClaudeHook` → `NotificationCenterService.notify(_:)` — this is the **"precisa de você"** path (permission/idle prompts), showing the hook's `message` as the body; it complements the transcript watcher below, which owns **"terminou"** (so no `Stop` hook, to avoid double notifications). Pass URL params **raw** — `open` percent-encodes them; pre-encoding causes double-encoding (`%2520`). Only works from the built `.app` (the scheme must be registered in Launch Services), same bundle-only constraint as notifications. (User hooks were blocked org-wide by `allowManagedHooksOnly` until 2026-07-08; the transcript watcher was built as a hook-free fallback and remains the robust path.)

**Session tracking (hook-free, via transcript).** Managed orgs can set `allowManagedHooksOnly: true` (delivered via remote/managed settings, e.g. `~/.claude/remote-settings.json`), which makes Claude Code silently ignore every user hook — so the URL-scheme path above never fires. The fallback needs no hooks and reads the Claude Code transcripts directly:

- `TranscriptWatcher` uses FSEvents to watch `~/.claude/projects/**/*.jsonl` (dir overridable via `CLAUDE_CONFIG_DIR`), reads new lines incrementally by byte offset (seeking to EOF on start so live history isn't replayed), and emits a `SessionActivity` per relevant line — `.turnEnded` for an `assistant` line whose `message.stop_reason` is `end_turn`/`stop_sequence`, else `.working` (skips `isSidechain` subagents). On start it also reads the *tail* of transcripts modified in the last 6h to reconstruct sessions already open (those events carry `isLive: false`). FSEvents gotcha: the stream MUST pass `kFSEventStreamCreateFlagUseCFTypes`, otherwise the callback's `paths` is a `char **` and casting it to `NSArray` segfaults.
- `SessionRegistry` (`@MainActor @Observable`, owned by `UsageModel`, exposed as `sessionRegistry`) is the source of truth: it applies each `SessionActivity`, derives status (`working` / `awaitingUser` / `idle` — a 30s sweep marks idle after 5min and forgets after 3h), and publishes a sorted `sessions` list for `PopoverView`'s "Sessões" section. Only sessions whose `cwd` has a live `claude` process are listed (at most one per live process per cwd) — `LiveSessionProbe` polls live cwds every 10s via `ps`/`lsof`, since the transcript can't tell a closed session from an idle one (macOS won't expose another process's env, and the process doesn't keep the `.jsonl` open). When a session hits `.turnEnded` **live**, it calls back into the turn-end notification (gated by the `notifyOnTurnEnd` UserDefault, default on; toggle in `SettingsView`). Turn-end is detectable; attention/permission is **not** (the transcript doesn't record it reliably).

The notification body shows the session's `aiTitle` (parsed from the transcript, cached per session) and the project as subtitle. Since notifications are denied by default until the user allows them once, `SettingsView` shows a warning + "open settings" button when `authorizationStatus == .denied`, and `NotificationCenterService` implements `willPresent` so the banner shows even when the app is foreground. (A click-to-focus-the-terminal feature was attempted and dropped: a `.accessory` app can't bring another app forward on macOS 14, and Warp exposes neither AppleScript nor an accessibility window tree.)

Set `CLAUDEGAUGE_DEBUG=1` to log parsed snapshot percentages, received hook URLs, and notification-scheduling results to stderr.

**Spend tracking (`Sources/ClaudeGauge/Spend/`).** The popover's **"Gastos"** tab estimates token spend by model and by project, computed entirely from the local transcripts — **there is no Anthropic API for subscription cost.** (Confirmed: Claude Code's own `/usage` computes the $ "locally from token counts / local session history"; the Admin Usage & Cost API — `/v1/organizations/usage_report/messages`, `/v1/organizations/cost_report` — needs an `sk-ant-admin01-…` key + a Console org and only covers **API-key-billed** usage, not subscription/OAuth usage. The Claude Code Analytics API is org-admin-scoped too. So the local approach is the only path here, and it mirrors what the CLI does — relevant only for a future B2B/team version.) `SpendAggregator` reads `~/.claude/projects/**/*.jsonl`, pre-filters files by mtime to the window and re-checks each line's `timestamp`, sums `message.usage` tokens (input/output/cache-creation/cache-read) per `message.model` and per `cwd`, and multiplies by a hardcoded price table (`ModelCatalog` in `ModelPricing.swift`) to get an **"equivalent-API" USD estimate** — cache write priced by TTL from the `cache_creation` breakdown (5m = 1.25×, 1h = 2× input; read = 0.1×), `<synthetic>` and unknown models skipped (their `pricing(forModel:)` is nil). It runs off the MainActor (`UsageModel.refreshSpend(periodDays:force:)` — 10-min throttle per period, cancel-and-replace via `spendTask` on period change, publishes `SpendReport` + `isComputingSpend`). `PopoverView` is split into **"Uso"** / **"Gastos"** tabs; the spend tab has a period filter (24h/7d/30d, persisted in the `spendPeriodDays` UserDefault) and a pulsing `SpendSkeleton` while computing. The popover forces `.preferredColorScheme(.dark)` so the system segmented control matches the fixed-dark `Palette`.

## Code signing (dev)

`make-app.sh` signs ad-hoc (`-`) by default, which changes the app identity every rebuild and makes macOS re-prompt for Keychain access. To avoid this, create a local self-signed code-signing certificate named `ClaudeGauge Dev` (see README) — the script auto-detects and uses it. Override with the `SIGN_IDENTITY` env var.
