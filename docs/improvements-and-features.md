# VektorTV: improvement and feature review

*Prepared 2026-10-11 against VektorTV **0.7.0** (commit `af1f8cd`). Covers the shared Rust core, the Tauri 2 desktop app (Windows/macOS) and the native SwiftUI apps (iOS/iPadOS/tvOS).*

This review comes from reading the source (`crates/`, `src-tauri/`, `src/`, `apps/apple/`), CI and the release/verification docs. It has three parts:

1. **20 existing features that can be improved**, with what the code does today and how to improve it.
2. **20 new features worth adding.**
3. **Online services, APIs and libraries** that could meaningfully improve the app, with caveats.

Each item is tagged with **Effort** (S = days, M = 1–2 weeks, L = several weeks), **Impact** (High/Med/Low) and **Platforms** (Core = Rust core, Desktop = Tauri, Apple = iOS/iPadOS/tvOS). The AGENTS.md cross-platform rule applies to every item: anything that changes behavior should reach both desktop and Apple, or the difference should be documented.

---

## At a glance: suggested priorities

| Priority | Items | Why |
|---|---|---|
| **Quick wins (≤ 1 week each)** | I-2 desktop M3U after restart, I-3 XMLTV concatenation fix (the bug alone), I-4 gzip EPG, I-11 Now Playing metadata, I-13 settings/account info, I-1 auto-reconnect | Fix real failures users will hit, using small, local code changes |
| **Next release theme: "Reliable TV"** | I-1, I-5, I-6, I-12, I-14, I-16, F-5, F-6 | Make the existing live-TV experience hard to break |
| **Following theme: "Guide 2.0"** | I-3, I-8, I-9, F-4, F-13, F-14 | The FTS5 index and streaming XMLTV import are a strong base. Build on them |
| **Big bets** | F-1 catch-up, F-2 VOD, F-3 recording, F-7 multiview, F-11 sync | These close the largest gaps against established IPTV players |

---

## Part 1: 20 features that can be improved

### I-1. Playback resilience: automatic reconnect
**Effort** M · **Impact** High · **Platforms** Desktop, Apple

**Today:** A dropped stream ends in a "Playback unavailable" state with a manual **Retry channel** button. Desktop maps libVLC states `ended`/`error` to failure in [PlayerView.tsx](../src/components/PlayerView.tsx). Apple fails on `AVPlayerItem.status == .failed` or after a fixed 30 s start timeout ([PlaybackStore.swift:56](../apps/apple/Shared/PlaybackStore.swift:56)). IPTV streams drop often (provider restarts, connection limits, Wi-Fi blips), so this is the most likely day-to-day annoyance.

**Improve by:**
- Adding a reconnect supervisor with exponential backoff (for example 1 s → 2 s → 5 s → 10 s, at most 5 attempts) and a visible "Reconnecting… (2/5)" state instead of an error.
- Detecting stalls as well as hard errors. On desktop, watch `MediaStats.decoded_video`/`displayed_pictures`, which are already read in [player.rs](../src-tauri/src/player.rs): no new frames for about 8 s while `playing` counts as a stall. On Apple, observe `AVPlayerItemPlaybackStalled`, `AVPlayerItemFailedToPlayToEndTime`, `isPlaybackLikelyToKeepUp` and `AVPlayerItemNewErrorLogEntry`.
- Reusing the existing request-id ordering so a reconnect can never override a newer user selection or Stop.
- Telling the user when a provider's connection limit is the likely cause (HTTP 403/509 or Xtream `max_connections`; see I-13).

### I-2. Desktop M3U channels fail after a restart
**Effort** S · **Impact** High · **Platforms** Desktop (Core)

**Today:** M3U stream locations are deliberately kept only in memory. On Apple, `Request::Stream` re-downloads the playlist when the in-memory map is empty ([vektortv-apple/src/lib.rs:244](../crates/vektortv-apple/src/lib.rs:244)). Desktop does not. After a restart within the 6-hour freshness window it returns *"Refresh the playlist before playing this cached channel."* ([commands.rs:451](../src-tauri/src/commands.rs:451)). M3U users therefore get a broken first play after every launch.

**Improve by:**
- Porting Apple's lazy re-fetch into `play_channel_inner`: fetch the playlist once on first play, guarded by the `syncing` flag, then play.
- Optionally, keeping a persistent encrypted stream map. Encrypt the `id → URL` map with AES-GCM using a key held in the OS keychain, so cold-start playback needs no playlist download while URLs stay out of plaintext SQLite.
- Adding a core-level test that both shells pass through the same "resolve stream" function, so the platforms can't drift again.

### I-3. XMLTV parser fidelity (including a concatenation bug)
**Effort** M · **Impact** High · **Platforms** Core (both UIs)

**Today:** [xmltv.rs](../crates/vektortv-core/src/xmltv.rs) keeps only `title`, `desc` and `category`, and appends every matching element's text ([xmltv.rs:171](../crates/vektortv-core/src/xmltv.rs:171)). Guides that ship several languages (`<title lang="en">…</title><title lang="nb">…</title>`) or several categories (`<category>Movie</category><category>Drama</category>`) produce glued strings such as `"MovieDrama"` or two titles run together. `sub-title`, `episode-num`, `icon`, `rating`, `star-rating`, `new`/`live`/`premiere`/`previously-shown` and `credits` are discarded.

**Improve by:**
- Choosing one `title`/`desc` by language preference (system locale, then `en`, then first). Join categories with a separator, or store them in a child table.
- Adding `subtitle`, `episode` (normalized from `xmltv_ns`/`onscreen`), `icon_url`, `rating` and flags (`is_new`, `is_live`, `is_premiere`) through a `user_version = 3` migration. Extend the FTS5 index to `subtitle`.
- Showing them in the UI: "S3 E7 · *Episode title*", **LIVE**/**NEW** badges, and programme artwork in details. This also enables F-4 (alerts for live sport) and F-14.
- Adding regression tests for multi-language titles and multiple categories next to the existing entity/CDATA test.

### I-4. Compressed, multiple and auto-discovered EPG sources
**Effort** S–M · **Impact** High · **Platforms** Core, both UIs (Settings)

**Today:** One XMLTV URL is streamed raw into the parser. `reqwest`'s `gzip` feature only handles `Content-Encoding`, so the common `.xml.gz` downloads offered by community EPG sites fail as "not a complete XMLTV guide". The `#EXTM3U x-tvg-url="…"`/`url-tvg` header that many playlists carry is ignored, because [m3u.rs](../crates/vektortv-core/src/m3u.rs) only reads attributes on `#EXTINF` lines.

**Improve by:**
- Sniffing the first two bytes (`1F 8B`) and wrapping the stream reader in `flate2::read::GzDecoder`. The existing bounded-queue design in `provider::guide` stays the same. The 1 GiB limit should apply to *decompressed* bytes as well, to block gzip bombs.
- Auto-filling the EPG URL from `x-tvg-url`/`url-tvg` when the user leaves it blank (comma-separated lists are common).
- Accepting several XMLTV URLs merged by priority (provider guide first, then supplementary sources for channels the provider lacks). Store them per connection in the keychain record, since they can contain credentials.

### I-5. Smarter guide-to-channel matching
**Effort** M · **Impact** High · **Platforms** Core, both UIs

**Today:** A programme matches by exact `epg_id`, or, failing that, when the XMLTV `channel` attribute equals a *unique* normalized channel name ([xmltv.rs:120](../crates/vektortv-core/src/xmltv.rs:120)). XMLTV `<channel><display-name>` elements are never read. Channels named `NO| NRK1 FHD` will rarely match a guide entry called `NRK1`, so many channels show "No programme information".

**Improve by:**
- Parsing `<channel id><display-name>…</display-name></channel>` (they come before programmes) and building a name index from them.
- Normalizing aggressively for matching: strip quality suffixes (`HD`, `FHD`, `UHD`, `4K`, `ᴴᴰ`, `+1`), provider prefixes (`NO|`, `[UK]`), punctuation and accents. Then compare with Jaro-Winkler (`strsim`) above a conservative threshold, and only when it is unambiguous.
- Allowing a per-channel manual **"Assign guide…"** override, stored in SQLite and kept across refreshes.
- Reporting coverage in Settings, for example "Guide covers 31,204 of 54,745 channels (57%)", so users know whether to add a supplementary source (I-4).

### I-6. Channel search quality and speed
**Effort** S–M · **Impact** Med · **Platforms** Core

**Today:** Channel search is `search_name LIKE '%term%'` over every row on each debounced keystroke ([store.rs:301](../crates/vektortv-core/src/store.rs:301)). Search is accent-sensitive, a test documents that `ALPHA` does not find `Álpha`, and results come in provider order with no relevance ranking. Programme search, by contrast, is accent-insensitive FTS5, so the two search boxes behave differently.

**Improve by:**
- Adding an FTS5 table over channel names with `tokenize='trigram remove_diacritics 1'`. The bundled SQLite is 3.50.2, newer than the 3.45 that introduced this option, so it works identically on every platform. This gives indexed substring search with accent folding.
- Ranking exact > prefix > substring, boosting favorites and recently watched channels, and also matching group names.
- Treating 1–2 character queries as prefix searches, since trigram search needs at least three characters.

### I-7. Country detection beyond group names
**Effort** M · **Impact** Med · **Platforms** Core

**Today:** Countries are inferred only from provider **group names** ([countries.rs](../crates/vektortv-core/src/countries.rs)). Any group without a recognizable country goes to *International & unassigned*, often including large "Sports", "Movies" or "4K" groups that are country-specific.

**Improve by:**
- Using channel-level signals: the `tvg-id`/`epg_id` suffix (`NRK1.no`, `BBCOne.uk`) and a lookup against the iptv-org channel database (see Part 3), which maps channel IDs to countries and categories.
- Moving from a per-group `country_groups` table to a per-channel country column, so a mixed group can be split correctly.
- Letting users reassign a group or channel to a country, stored as an override and applied after each import.

### I-8. Desktop TV Guide grid
**Effort** M · **Impact** Med · **Platforms** Desktop

**Today:** [Guide.tsx](../src/components/Guide.tsx) shows a fixed 3-hour window that moves in 2-hour steps from −6 h to +40 h. It is mouse-only (double-click to watch), has no day picker, and every programme looks the same.

**Improve by:**
- Keyboard navigation: arrows move between cells, Enter watches, PgUp/PgDn scroll channels, `N` jumps to now.
- Zoom levels (1.5 h / 3 h / 6 h), a day-and-time jump menu covering the full imported window, and horizontal trackpad scrolling.
- Colour-coding by category once I-3 lands (sport, news, film, kids), plus LIVE/NEW badges and episode lines.
- Highlighting favorites' rows and offering a "favorites only" toggle in the guide header.

### I-9. Apple TV and iPad guide
**Effort** L · **Impact** Med · **Platforms** Apple

**Today:** Native Apple uses per-channel schedule lists ([ScheduleView.swift](../apps/apple/Shared/ScheduleView.swift)) rather than a time grid. On Apple TV and large iPads, viewers expect the "channels × time" grid that desktop already has.

**Improve by:**
- Building a focus-driven grid for tvOS and regular-width iPad, using a `UICollectionView` compositional layout (or a custom SwiftUI `Layout`) with a sticky time ruler and channel column, and the focus engine moving cell-to-cell. Keep the list on iPhone.
- Reusing the desktop's batched `guide_schedules`-style reads so scrolling never triggers provider requests.

### I-10. Desktop player controls and stream information
**Effort** M · **Impact** Med · **Platforms** Desktop (Apple partly)

**Today:** Desktop offers play/pause/stop/volume. Volume resets to 80 on every launch, and `--network-caching=1200` is fixed ([player.rs:142](../src-tauri/src/player.rs:142)). Audio language, subtitles/teletext, aspect ratio, crop and deinterlacing are not exposed, even though libVLC 3 supports all of them. Stream information is limited to resolution.

**Improve by:**
- Binding the libVLC 3 functions `libvlc_audio_get_track_description`/`set_track`, `libvlc_video_get_spu_description`/`set_spu`, `libvlc_video_set_aspect_ratio`, `libvlc_video_set_crop_geometry`, `libvlc_video_set_deinterlace` and `libvlc_audio_set_mute`, and adding a compact "Audio & subtitles" menu.
- Persisting volume, mute and per-channel audio-language preference.
- Making buffering configurable: Low latency (600 ms), Balanced (1200 ms) or Stable (3000 ms).
- A "Stream info" popover built from the `MediaStats` already read: bitrate, codec, corrupted/discontinuity counters and dropped frames. This also helps users diagnose provider problems.
- On Apple, exposing `AVMediaSelectionGroup` audio/subtitle choices inline as well as in full screen.

### I-11. Now Playing metadata and system media integration
**Effort** S–M · **Impact** Med · **Platforms** Apple, Desktop

**Today:** AVPlayer items carry no metadata, so the tvOS info panel, iOS Control Center, Lock Screen and Siri "what's on?" show nothing about the programme. Desktop does not handle hardware media keys or the Windows/macOS media overlays.

**Improve by:**
- **Apple:** setting `AVPlayerItem.externalMetadata` (title = programme, subtitle = channel, description, genre, artwork = channel logo) and refreshing it at programme boundaries. On iOS, also feed `MPNowPlayingInfoCenter` and handle `MPRemoteCommandCenter` play/pause and next/previous channel (ties into F-5).
- **Desktop:** using the `souvlaki` crate (SMTC on Windows, MPNowPlayingInfoCenter on macOS) for media keys and OS "now playing" overlays.

### I-12. Channel logos: caching, privacy and fallbacks
**Effort** M · **Impact** Med · **Platforms** Core, Desktop, Apple

**Today:** The desktop webview loads logos straight from provider URLs (CSP allows `img-src https: http:`; see [tauri.conf.json:26](../src-tauri/tauri.conf.json:26)). Apple uses `AsyncImage`, which has no persistent cache. Logos are re-downloaded often, slow hosts stall rows, every logo host learns the viewer's IP and viewing pattern, and missing logos fall back to a generic TV icon.

**Improve by:**
- A Rust logo cache: download once, downscale to about 128 px, store under app data with ETag/expiry, and serve to the webview through a Tauri custom protocol (`logo://<channel-id>`). Then tighten the CSP so images can only come from the app and that protocol.
- On Apple, using `Nuke`/`NukeUI` (disk cache, prefetching, request coalescing) or serving the same cached files through the Rust core.
- Fallback logos from community logo sets keyed by `tvg-id`/name (see Part 3), and a generated monogram (initials on a channel-specific colour) instead of the generic icon.

### I-13. Settings and account management
**Effort** S · **Impact** Med · **Platforms** Desktop, Apple, Core

**Today:**
- The desktop form always starts empty, so changing only the EPG URL means re-entering the password ([Settings.tsx](../src/components/Settings.tsx)).
- Xtream's `user_info` (expiry date, max/active connections, trial flag) is checked and then discarded ([provider.rs:143](../crates/vektortv-core/src/provider.rs:143)).
- The Apple connection form defaults to `http://ourxtream.com` in Release builds ([CoreModels.swift:5](../apps/apple/Shared/CoreModels.swift:5)).
- The desktop version tag falls back to `v0.4.0` ([Settings.tsx:66](../src/components/Settings.tsx:66)), and the README heading still says "Features in 0.6.1".

**Improve by:**
- Prefilling non-secret fields and leaving the password blank, meaning "keep the saved password".
- Returning and showing account status: "Expires 12 Nov 2026 · 1 of 2 connections in use", with a warning banner 7 days before expiry.
- Using provider-neutral placeholders in Release. Keep the development default in Debug only.
- Smarter input: strip `get.php`/`player_api.php` from pasted server addresses, and when a pasted M3U URL looks like `get.php?username=…&password=…`, offer to convert it to an Xtream login (richer API, short EPG, catch-up later).
- Fixing the stale version fallback and README heading.

### I-14. Network errors and diagnostics
**Effort** S–M · **Impact** Med · **Platforms** Core, both UIs

**Today:** Every transport failure becomes the same `Error::Network` message ([provider.rs:118](../crates/vektortv-core/src/provider.rs:118) and others). There is one 600 s whole-request timeout and no retry for transient failures. When a refresh fails, there is nothing to look at beyond the banner text.

**Improve by:**
- Classifying `reqwest` errors (`is_timeout`, `is_connect`, TLS/certificate, DNS, body decode) into actionable messages, for example "The server didn't answer within 15 s" versus "The certificate is not trusted".
- Retrying idempotent GETs with jittered backoff, using the `backon` crate or a small hand-written loop, and using separate read-idle timeouts for long XMLTV streams.
- A **Diagnostics** panel listing the last refresh times and durations, catalog/guide sizes, match coverage (I-5), player engine version and recent errors. Add "Copy redacted report". Redaction matters: Xtream URLs carry the username and password in the path, so scrub `/live/<user>/<pass>/` and query strings.

### I-15. Library performance and sync progress
**Effort** M · **Impact** Med · **Platforms** Core, Desktop

**Today:**
- `Store::list` runs two extra queries per channel for now/next, so a 100-row page costs about 200 extra queries ([store.rs:345](../crates/vektortv-core/src/store.rs:345)).
- A guide import collects every matched programme in memory before a single replace transaction.
- Progress is text only, with no percentage or cancel.
- Desktop polls `player_status` every second through a blocking task ([App.tsx:311](../src/App.tsx:311)).
- Apple re-fetches groups and countries on every list reload ([LibraryStore.swift:129](../apps/apple/Shared/LibraryStore.swift:129)), so each search keystroke makes three core calls.

**Improve by:**
- Computing now/next in one query, for example with a window function over `programmes` joined to the page's channel ids.
- Streaming parsed programmes into a staging table in chunks, then swapping atomically (`DELETE` + `INSERT … SELECT`, or a rename) to cut peak memory. The current safety rule still holds: a failed import keeps the old guide.
- Byte-based progress for XMLTV (`Content-Length` when present), plus a **Cancel** button wired to a cancellation token.
- Pushing player state changes from Rust (`app.emit`) instead of polling. On Apple, refresh groups/countries only when the catalog revision changes.

### I-16. Favorites and history that survive provider changes
**Effort** M · **Impact** High · **Platforms** Core, Apple

**Today:** Favorites and history are keyed by namespaced channel ID. For M3U, that ID is a hash of the **stream URL** ([m3u.rs](../crates/vektortv-core/src/m3u.rs)), so a provider that rotates tokens or renumbers streams silently wipes favorites. History keeps only the last-watched timestamp. On Apple TV the whole database, favorites included, lives in the purgeable Caches directory ([CoreClient.swift:9](../apps/apple/Shared/CoreClient.swift:9)).

**Improve by:**
- Storing a secondary "identity" for each favorite (`epg_id`, normalized name, group, logo URL). After each import, re-link favorites whose ID disappeared to the best unambiguous match.
- Splitting user data (favorites, country favorites, history, overrides, settings) into a small separate database or file. On iOS keep it in Application Support. On tvOS mirror it to `NSUbiquitousKeyValueStore` (iCloud, small key-value data), which survives cache purges and enables F-11.
- Adding favorite reordering, watch-time history ("Most watched"), and a **Clear history** action.

### I-17. Browsing very large catalogs
**Effort** M · **Impact** Med · **Platforms** Desktop, Apple

**Today:** With the observed 54,745-channel catalog, the desktop group picker is a plain `<select>` with no search ([ChannelBrowser.tsx:163](../src/components/ChannelBrowser.tsx:163)), while Apple's group sheet is searchable. The desktop channel list keeps appending rows ("Load more channels") without virtualization, so the DOM grows as you scroll. Ordering is fixed to provider order, or A–Z inside a country.

**Improve by:**
- A searchable group combobox on desktop that matches Apple's `.searchable` group sheet.
- Virtualizing the desktop channel list. The guide already virtualizes rows, so reuse that approach.
- Sort options (provider order / A–Z / most watched / channel number once F-5 adds numbers), an A–Z jump index on tvOS, and a "Recently added channels" view built by diffing imports.

### I-18. Accessibility and localization
**Effort** M · **Impact** Med · **Platforms** Desktop, Apple

**Today:** All UI strings are hard-coded English in React and Swift. The verification docs list VoiceOver, accessibility text sizes and reduced-motion behavior as unverified.

**Improve by:**
- Moving Apple strings into a String Catalog (`.xcstrings`) and desktop strings into a message catalog (for example `i18next` or FormatJS). Ship Norwegian Bokmål first, alongside English.
- An accessibility pass: `aria-live` announcements for player state ("Connecting", "Live", "Reconnecting"), keyboard focus order and visible focus in the desktop guide, a contrast check of teal-on-charcoal text, Dynamic Type on iOS, and VoiceOver labels for the guide grid once I-9 lands.

### I-19. Test coverage and release automation
**Effort** M–L · **Impact** High (long-term) · **Platforms** All

**Today:**
- The Rust core has good unit tests.
- The frontend has two unit tests ([utils.test.ts](../src/utils.test.ts)) and no component or end-to-end tests.
- Apple UI tests need a live provider account and a specific channel (NRK1).
- Desktop installers are unsigned on Windows and ad-hoc signed without notarization on macOS.
- TestFlight uploads are run locally by hand.

**Improve by:**
- A **fake provider** test server (an `axum` binary or the `wiremock` crate) serving fixture Xtream JSON, M3U, gzip XMLTV and a short looping HLS/TS clip. Then core integration tests, desktop end-to-end tests and Apple UI tests can run deterministically in CI without credentials.
- React component tests with Vitest + Testing Library, and Playwright against `?demo=1` for layout regressions at 1024 px and 1440 px.
- Signing: Windows Authenticode (see Part 3 for eligibility caveats), macOS Developer ID plus `notarytool` in CI, and an App Store Connect API key so the TestFlight steps in AGENTS.md can run in CI or Xcode Cloud (the scripts already exist).

### I-20. Code structure and shared types
**Effort** M · **Impact** Med (velocity) · **Platforms** Desktop, Apple, Core

**Today:** [App.tsx](../src/App.tsx) is about 750 lines with roughly 30 `useState` hooks, duplicated query construction and several hand-rolled interval loops. DTOs are maintained by hand in three places: Rust `models.rs`, TypeScript `types.ts` and Swift `CoreModels.swift`.

**Improve by:**
- Extracting `usePlayer`, `useLibrary`, `useSync` and `useWindowMode` hooks. Consider TanStack Query for request de-duplication, cancellation and cache invalidation in place of the custom `RequestSequence`/`revision` counters.
- Generating TypeScript and Swift types from Rust (`specta`/`ts-rs` for TypeScript, `typeshare` for Swift), so a field added in the core can't silently go missing on one platform.
- Adding a single Rust-side `ResolveStream`/`Playback` service used by both shells (also the I-2 fix).

---

## Part 2: 20 features worth adding

### F-1. Catch-up and archive playback
**Effort** L · **Impact** High · **Platforms** Core, Desktop, Apple

Many Xtream providers expose recent programmes through `tv_archive`/`tv_archive_duration` on live streams and a `/timeshift/{user}/{pass}/{duration}/{start}/{stream_id}.ts|.m3u8` endpoint. M3U playlists signal catch-up with `catchup`, `catchup-days` and `catchup-source` attributes. Today the guide says past programmes "tune the current live broadcast" ([README](../README.md)).

- **Core:** parse the archive fields and M3U catch-up attributes, add `archive_days` per channel, and build timeshift URLs. Support the common `default`, `append`, `shift` and `flussonic` modes; there is a Rust crate for this (Part 3).
- **UI:** a "⟲ Watch from start" action on past and current programmes in the guide and search results, plus a seekable timeline in the player.
- **Caution:** there is no official Xtream specification, and the duration unit (minutes or seconds) varies, so test it per provider.

### F-2. Movies and series (VOD) with resume
**Effort** L · **Impact** High · **Platforms** All

The README lists VOD/series as future work. The Xtream API exposes `get_vod_categories`, `get_vod_streams`, `get_vod_info`, `get_series` and `get_series_info`, and M3U playlists often mix VOD groups in.

- Add a **Movies** and a **Series** tab with poster grids, season/episode lists and plot text (provider data first, TMDB enrichment as an option; see Part 3).
- Store resume positions and a "Continue watching" row. Apple: `AVPlayer` seeking. Desktop: `libvlc_media_player_set_time`.
- Keep the catalog import separate from live import, so a failed VOD import never affects live TV, matching the existing "separate success boundaries" principle.

### F-3. Recording and pause-live
**Effort** L · **Impact** Med–High · **Platforms** Desktop first

- **Pause live / rewind buffer:** VLC's input timeshift (`--input-timeshift-path`/granularity) lets desktop pause and resume live TV. On Apple, use the HLS DVR window when the provider supplies one.
- **Recording (desktop):** schedule from the guide ("Record this programme"). Record the raw TS stream (`:sout=#std{access=file,…}` on a second libVLC media, or a plain HTTP download for `.ts` streams) with padding, a recordings library and disk-space checks. Respect provider connection limits, since a recording uses a connection.
- Keep this personal and local. Make it clear that recording rights depend on the user's subscription and jurisdiction.

### F-4. Reminders and saved-search alerts
**Effort** M · **Impact** High · **Platforms** All

The FTS5 programme index already makes this cheap.

- **Remind me** on any future programme: a desktop notification via `tauri-plugin-notification`, a local notification on iOS (`UNUserNotificationCenter`), and an in-app banner on tvOS, with "Watch now" switching channel.
- **Saved searches / watchlist**, for example "Champions League", "Formula 1" or a favourite series title, re-run after each guide import. Matches are highlighted in the guide and can trigger reminders.

### F-5. Fast channel zapping
**Effort** M · **Impact** High · **Platforms** All

Today, changing channel in full screen means leaving full screen.

- **Desktop:** `↑/↓` or `PgUp/PgDn` for the next/previous channel in the current list, number keys for channel numbers, `Backspace`/`L` for the previous channel, and `M` for mute. Show an on-screen channel banner (logo, number, now/next) for a few seconds.
- **Apple TV:** swipe/click up or down in full screen to zap within the current list, using a custom overlay (`customOverlayViewController` / `customInfoViewControllers`) for a mini-guide. Add a remote shortcut for the previous channel, checking that it doesn't conflict with AVKit's own gestures.
- **Channel numbers:** parse M3U `tvg-chno` and Xtream `num` (currently ignored) and allow user-assigned numbers.

### F-6. Channel failover and duplicate merging
**Effort** M · **Impact** High · **Platforms** Core, both UIs

Large catalogs list the same channel several times (`NRK1 HD`, `NRK1 FHD`, `NRK1 (backup)`, across groups).

- Cluster duplicates by `epg_id` plus normalized name (sharing the I-5 normalization). Show one row with a quality selector.
- When a stream fails or stalls (I-1), **automatically fail over** to the next variant, and remember which variant works best on this device.
- Optional background "health check" of favorite channels (a short probe of the HLS playlist or TS stream) to flag dead channels before the user clicks.

### F-7. Multiview and picture-in-picture everywhere
**Effort** L · **Impact** Med–High · **Platforms** All

- **Desktop:** a 2×2 or 1+3 grid with one libVLC player per tile and audio on the focused tile. This suits sports nights. Watch provider connection limits.
- **iPad:** a grid of `AVPlayerLayer`s in regular-width layouts.
- **Inline PiP on iOS/iPadOS:** attach `AVPictureInPictureController` to the inline `AVPlayerLayer`, so PiP works without entering full screen. Today it is only enabled on the full-screen `AVPlayerViewController`.
- **Desktop mini-player:** the 0.7.0 popout already covers most of this. Add an optional borderless/rounded style and corner snapping.

### F-8. Custom lineups: hide, rename, reorder
**Effort** M · **Impact** High · **Platforms** All

With tens of thousands of channels, most users care about a few hundred.

- Hide groups, countries or channels, with a "show hidden" toggle and stats.
- Custom groups ("My sports", "Kids") with drag-and-drop ordering, plus channel renames and logo overrides.
- Store everything as overrides keyed by the stable identities from I-16, so they survive refreshes.

### F-9. Parental controls and profiles
**Effort** M · **Impact** Med · **Platforms** All

- A PIN lock for chosen groups or countries, and an "adult content" filter that recognizes common markers (`XXX`, `Adult`, `18+`) plus XMLTV ratings once I-3 lands.
- Lightweight **profiles** (for example "Family", "Kids", "Me") with separate favorites, history and hidden lists. On tvOS, consider the system's multi-user support (the User Management entitlement) so each household member gets their own data automatically.

### F-10. Multiple providers
**Effort** L · **Impact** Med · **Platforms** Core, both UIs

The README lists this as future work. The namespace design (account-scoped channel IDs) already supports it.

- Store several connections (keychain entries keyed by namespace), import each into its own namespace, and browse them merged or per provider.
- Pair with F-6 so the same channel from two providers becomes an automatic failover.

### F-11. Cross-device sync of favorites, history and settings
**Effort** M (Apple) / L (Desktop) · **Impact** High · **Platforms** All

- **Apple:** `NSUbiquitousKeyValueStore` for small data (favorites, country favorites, custom lineups) or CloudKit's private database for larger history, giving automatic sync between iPhone, iPad and Apple TV. This also fixes the tvOS cache-purge risk (I-16).
- **Desktop and cross-ecosystem:** start with **Export/Import** (a JSON file of favorites, overrides and settings, plus "Export favorites as M3U" for use in other players). Later, consider an optional sync backend (see Part 3) or file-based sync through a user-chosen iCloud Drive/OneDrive folder.
- Never sync stream URLs or passwords in plaintext.

### F-12. Easy Apple TV sign-in
**Effort** M · **Impact** High (onboarding) · **Platforms** Apple

Typing an Xtream server, username and password with the Siri Remote is the worst onboarding step.

- **Option A, iCloud Keychain:** save the connection as a synchronizable Keychain item (`kSecAttrSynchronizable`). Today it is `…ThisDeviceOnly` ([CredentialStore.swift:30](../apps/apple/Shared/CredentialStore.swift:30)). Set up once on iPhone and Apple TV picks it up. Make this opt-in, since it is a security trade-off.
- **Option B, local pairing:** Apple TV shows a QR code and a short code. The iPhone app (or a browser on the same network, served by a tiny local web form via `Network.framework`) sends the connection over the LAN, encrypted.
- Also accept a pasted M3U URL or an "Import connection" file on iOS and desktop.

### F-13. Home / Discover screen
**Effort** M · **Impact** Med–High · **Platforms** All

A landing view that answers "what should I watch?" using data the app already has:
- **On now in your favorites** (with progress bars), **Starting in the next hour**, **Continue watching** (recent channels), **Live sport now** (from categories and LIVE flags, I-3), and **Matches for your saved searches** (F-4).
- On tvOS this also feeds the Top Shelf (F-16).

### F-14. Rich programme details
**Effort** M · **Impact** Med · **Platforms** All

- A programme detail sheet with artwork, episode/season, cast, rating, and "Other airings" (an FTS query for the same title), plus Remind me and Record actions.
- Use XMLTV `icon`/`credits` first, and optionally enrich films and series from TMDB (non-commercial use with attribution; see Part 3).

### F-15. Casting: AirPlay, Chromecast, DLNA
**Effort** M · **Impact** Med · **Platforms** Apple, Desktop

- **Apple:** add an `AVRoutePickerView` button in the inline viewing room so AirPlay is reachable without entering full screen. Keep `allowsExternalPlayback` enabled and test AirPlay video to an Apple TV.
- **Desktop:** cast the stream URL to Chromecast through a Rust Cast client (Part 3). Xtream `.m3u8` URLs suit the Default Media Receiver. Bear in mind the cast device needs network access to the provider and the URL contains credentials.

### F-16. Apple system integration: Top Shelf, Siri, widgets, deep links
**Effort** M · **Impact** Med · **Platforms** Apple

- **Top Shelf extension (tvOS):** a sectioned row of favorites with live programme titles that deep-links straight into playback (`vektortv://play/<channel-id>`).
- **App Intents:** "Play NRK1 on VektorTV", "What's on Eurosport?" plus Shortcuts actions and Spotlight entries for favorites.
- **iOS widgets (WidgetKit):** "On now on my favorites" and "Next reminder".

### F-17. Desktop distribution niceties: auto-update, single instance, deep links, tray
**Effort** M · **Impact** Med–High · **Platforms** Desktop

- `tauri-plugin-updater` with signed update manifests on GitHub Releases. Updates must be signed, and the README notes "Automatic updates are not configured".
- `tauri-plugin-single-instance` (a second launch focuses the existing window), `tauri-plugin-deep-link` (`vektortv://` links, shared with F-16), and a system-tray/menu-bar menu with play/pause, favorites and "Show window".
- `tauri-plugin-global-shortcut` for an optional system-wide play/pause and next/previous channel.

### F-18. More source types
**Effort** M per source · **Impact** Med · **Platforms** Core

- **HDHomeRun** network tuners (local `discover.json`/`lineup.json`), **Tvheadend** and **Jellyfin/Emby Live TV**, which bring over-the-air and self-hosted TV into the same guide.
- **Local M3U/XMLTV files** (file picker and drag-and-drop on desktop; Files app on iOS).
- Each source becomes another namespace (pairs naturally with F-10).

### F-19. Radio mode, audio-only and sleep timer
**Effort** S–M · **Impact** Med · **Platforms** All

- IPTV catalogs often include radio groups. Detect them (group names, no video track) and show a **Radio** view with large logos and Now Playing metadata (I-11).
- **Audio-only mode** for TV channels on iPhone, which saves data and works on the lock screen. The `audio` background mode is already declared.
- **Sleep timer** (15/30/60 min or end of programme), especially useful on Apple TV and in bed on iPad.

### F-20. Quality and data-saver controls
**Effort** S–M · **Impact** Med · **Platforms** Apple, Desktop

- On Apple, `preferredPeakBitRate`/`preferredMaximumResolution` with "Auto / Data saver / Best", and a separate default for cellular (`NWPathMonitor`).
- On desktop, choose the preferred variant (`.ts` versus `.m3u8` for Xtream) and a buffer profile (I-10).
- Show the current bitrate in stream info, and a one-tap "Connection test" against the provider (latency and throughput) in Diagnostics (I-14).

---

## Part 3: Online services, APIs and libraries

Research done 2026-10-11. Licences, prices and availability change, so the caveats below come from the sources listed. Verify them before adopting anything.

### A. Guide data, metadata and logos

| Resource | What it offers | How it helps VektorTV | Caveats |
|---|---|---|---|
| **[iptv-org/api](https://github.com/iptv-org/api)** | Public JSON (GitHub Pages): `channels`, `feeds`, `logos`, `guides`, `categories`, `countries`, `languages`, `timezones`, `blocklist` | Country/category inference from channel IDs (I-7), logo fallback (I-12), guide-matching bridge (I-5), radio/kids/sport categorization (F-13, F-19). Cache it locally and refresh weekly | Schema versions differ between mirrors; the GitHub README is authoritative. Community data, so treat it as hints, like group names today |
| **[iptv-org/epg](https://github.com/iptv-org/epg)** | Node.js grabbers for hundreds of sites; Docker image serves `guide.xml` daily | A self-hosted supplementary XMLTV for channels your provider lacks (with I-4 multi-source) | Sites change or block scrapers; a server-side tool, not something to embed in the apps |
| **Community XMLTV feeds** such as [globetv.app EPG](https://github.com/globetvapp/epg) (daily, per country, GPL-3.0 data) and [Freeview-EPG](https://git.tdem.in/dp247/Freeview-EPG) (UK, 48 h, every 8 h); EPGSHARE01 is also widely used | Ready-made per-country XMLTV, often `.xml.gz` | Fills guide gaps with zero infrastructure once gzip and multi-source support exist (I-4). Other tools such as [Dispatcharr](https://www.mintlify.com/Dispatcharr/Dispatcharr/features/epg) auto-detect `.gz`/`.zip` the same way | Reliability and licensing vary per feed. Let the user add them rather than bundling them |
| **Schedules Direct** ([MythTV wiki](https://www.mythtv.org/wiki/TMS)) | Paid, high-quality listings (historically about US$25/year; originally US/Canada) | Optional premium guide for North American users | Current price and coverage not confirmed; check schedulesdirect.org |
| **[TMDB API](https://developer.themoviedb.org/docs/faq)** | Film/series artwork, overviews, cast, ratings | Programme details (F-14) and VOD enrichment (F-2) | Free for **non-commercial** use with attribution ("This product uses the TMDB API but is not endorsed or certified by TMDB"); commercial use needs a licence. TMDB does not own the images |
| **TheSportsDB** | Sports events, leagues, TV-broadcast data (v2) | A "Live sport" view (F-13) that links fixtures to channels | Free tier reportedly reduced or removed for many leagues ([Teamarr notes](https://www.mintlify.com/Pharaoh-Labs/teamarr/reference/provider-tsdb), [release note](https://newreleases.io/project/github/Pharaoh-Labs/teamarr/release/v2.15.0)); expect a premium key |
| **[tv-logo/tv-logos](https://github.com/tv-logo/tv-logos)** | 512 px PNG logos by country, made for dark backgrounds | Matches the charcoal Cinema theme for fallback logos (I-12) | CC BY-SA / BY-NC-SA, personal use; logos are trademarks. Fetch on demand per user rather than bundling |

### B. Playback engines

| Library | What it offers | How it helps | Caveats |
|---|---|---|---|
| **libVLC 4.x** | Asynchronous stop/pause, rewritten clock | Would remove much of the off-main-thread stop/teardown work in `player.rs`/`main.rs` | Still nightly-only as of May 2026 ([TV-Lite VLC4 port notes](https://www.tv-lite.com/news/58/36/TV-Lite-VLC4-porting-effort)). Watch it, don't adopt yet |
| **libmpv** via [`tauri-plugin-libmpv`](https://classic.yarnpkg.com/en/package/tauri-plugin-libmpv-api) | mpv engine for Tauri 2 (MPL-2.0) | An alternative desktop engine with strong HW decoding and scripting. The IPTV project MaxVideoPlayer ([mirror](https://gitblind.noratr.app/MaxMB15/MaxVideoPlayer)) shows native-view embedding | Early project (0.3.x, low health score); true in-layout embedding is hard ([Tauri discussion](https://github.com/orgs/tauri-apps/discussions/6343)). Only worth it if VLC limits bite |
| **[KSPlayer](https://swiftpackageregistry.com/kingslay/KSPlayer)** | AVPlayer + FFmpeg engine for iOS/tvOS/macOS; used by several IPTV apps | **Fallback engine on Apple** for MPEG-TS and non-HLS streams that AVPlayer rejects, bringing Apple closer to desktop VLC compatibility | **GPL by default**; an LGPL build exists with different features. Confirm MPEG-TS with real streams |
| **[MPVKit](https://github.com/mpvkit/MPVKit)** | libmpv + FFmpeg for iOS/macOS/tvOS (LGPL; GPL variant) | The same fallback idea with mpv's engine | README says it is mainly for learning and not frequently maintained; Metal support patch-level |
| **VLCKit / TVVLCKit 3.x** ([registry](https://swiftpackageregistry.com/videolan/vlckit)) | Official VLC for Apple (LGPL) | The most mature non-AVPlayer option, and the same engine as desktop | 3.3.x is the current official line; no official VLCKit 4 found |

**Recommendation:** keep AVPlayer as the primary engine on Apple, because it gives PiP, AirPlay, system UI and power efficiency. Add an *optional* fallback engine (VLCKit or an LGPL KSPlayer build) only for channels AVPlayer fails on, behind a setting.

### C. Platform integration

| Library or API | Use in VektorTV |
|---|---|
| **[souvlaki](https://github.com/Sinono3/souvlaki)** (Rust) | One API for Windows SMTC, macOS Now Playing and Linux MPRIS: media keys and the OS "now playing" overlay on desktop (I-11). Windows needs the window HWND, which the app already uses for VLC |
| **AVKit `externalMetadata`** ([Apple docs](https://developer.apple.com/documentation/avkit/customizing-the-tvos-playback-experience)), `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | Programme title/description/artwork in the tvOS info panel, Control Center and Lock Screen (I-11) |
| **TVServices Top Shelf** ([`TVTopShelfContentProvider`](https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider)) | Favorites and "on now" on the Apple TV home screen with deep links (F-16) |
| **App Intents, WidgetKit, `AVPictureInPictureController`, `AVRoutePickerView`** | Siri/Shortcuts (F-16), widgets (F-16), inline PiP (F-7), AirPlay button (F-15) |
| **`NSUbiquitousKeyValueStore` / CloudKit** | iCloud sync of favorites, lineups and history across Apple devices, plus tvOS cache-purge protection (I-16, F-11) |
| **Official Tauri 2 plugins**: [updater](https://v2.tauri.app/plugin/updater/), single-instance, deep-link, notification, global-shortcut, log | Auto-updates (signatures mandatory), app focus on relaunch, `vektortv://` links, reminders, system-wide shortcuts and a redacted diagnostic log (F-17, F-4, I-14). `window-state` is already in use |
| **[rust_cast](https://docs.rs/crate/rust_cast)** / **[oxicast](https://docs.rs/crate/oxicast/latest)** | Chromecast from the desktop app (F-15). oxicast documents HLS loading but is very early (0.0.x); rust_cast is more established |

### D. Data, search and parsing

| Library or feature | Use in VektorTV |
|---|---|
| **SQLite FTS5 `trigram` tokenizer with `remove_diacritics 1`** ([check-in](https://sqlite.org/cgi/src/info/0d50172477064dce), [GRDB note on 3.45+](https://github.com/groue/GRDB.swift/pull/1655)) | Indexed, accent-insensitive substring search for channel names (I-6). The bundled SQLite is **3.50.2**, so it works on every platform without depending on Apple's system SQLite |
| **`flate2`** (or `async-compression`) | Transparent `.xml.gz` guide support in the streaming parser (I-4) |
| **`strsim`** (Jaro-Winkler) / **`nucleo`** (fuzzy matcher) | Guide matching (I-5), duplicate clustering (F-6), typo-tolerant search |
| **[crispy-catchup](https://docs.rs/crispy-catchup)** and the [UniPlayer catch-up spec](https://uniplayer.net/docs/specs/catchup/) | Reference for M3U `catchup` modes and Xtream archive auto-detection (F-1). Evaluate the crate's maturity, or reimplement the few URL templates |
| **`specta`/`ts-rs`** (TypeScript) and **`typeshare`** (Swift) | Generate DTOs from Rust so `types.ts` and `CoreModels.swift` can't drift (I-20) |
| **`backon`** | Retry with backoff for idempotent provider requests (I-14) |
| **[Nuke/NukeUI](https://swiftpackageregistry.com/kean/nuke)** | Disk-cached, prefetching logo loading on iOS/tvOS (I-12) |

### E. Distribution, quality and observability

| Service or tool | Use in VektorTV | Caveats |
|---|---|---|
| **Azure Artifact Signing** (formerly Trusted Signing) ([DevClass, Jan 2026](https://devclass.com/2026/01/14/code-signing-windows-apps-may-be-easier-and-more-secure-with-new-azure-artifact-service/)) | Cheapest route to signed Windows installers (reported US$9.99/month for 5,000 signatures), removing SmartScreen warnings | GA reported only for organizations/individuals in USA/Canada and **organizations** in EU/UK. **Norway (EEA, non-EU) eligibility is unclear**, so check before planning around it. Alternatives: SSL.com eSigner, DigiCert KeyLocker |
| **Apple Developer ID + `notarytool`** | Notarized macOS DMG; you already have the Apple team for TestFlight | Requires the Developer ID certificate in CI secrets |
| **App Store Connect API key + Xcode Cloud** | Automates the AGENTS.md TestFlight steps (the Xcode Cloud scripts are already in the repo) | Rust toolchain setup in Xcode Cloud must stay pinned (already scripted) |
| **Sentry**: [`tauri-plugin-sentry`](https://cdn.jsdelivr.net/npm/tauri-plugin-sentry-api@0.5.0/README.md) for desktop, [sentry-cocoa](https://docs.sentry.io/platforms/apple/guides/tvos/features) for Apple | Opt-in crash and error reporting, including native minidumps on desktop | **Must scrub URLs**: Xtream paths contain credentials. Sentry's docs conflict on official tvOS support. Make it strictly opt-in |
| **[TelemetryDeck](https://telemetrydeck.com/press/)** | Privacy-first, anonymized usage analytics with a Swift SDK and a free tier | Free-tier size and tvOS support not confirmed in sources. Only add if usage data would change decisions |
| **`wiremock` / small `axum` fake provider** | Deterministic Xtream/M3U/XMLTV/HLS fixtures for CI (I-19) | You need to create a few seconds of royalty-free test video |

---

## Notes and assumptions

- Code references point to 0.7.0 (`af1f8cd`). Line numbers will drift as the code changes.
- Desktop runtime behavior on Windows and physical-device behavior on Apple were not re-verified for this review. Items marked "Today" are based on reading the source, not on new runtime tests.
- Any feature that adds a new external service should keep the current privacy stance: credentials only in the OS keychain, no stream URLs in SQLite or logs, and no third-party calls that reveal what the user watches without an explicit opt-in.
