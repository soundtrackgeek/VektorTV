# Changelog

All notable changes are recorded here. Versions follow semantic versioning.

## [0.2.1] - 2026-10-01

### Fixed

- Apple TV channel search and browsing use the available screen height with a compact header and an on-demand system keyboard, replacing the oversized search/title area that left only two or three rows visible.
- Keep the focused channel row visible while scrolling in either direction and moving between playback, favorite and programme-guide actions; highlight the full row.
- Scale the fallback TV logo to fit its reserved space so it cannot overlap channel names.
- Start channel lists at the top when changing search, group or library section.

## [0.2.0] - 2026-09-30

### Added

- Native SwiftUI applications for iOS/iPadOS 18+ and tvOS 18+, sharing the Rust IPTV core through a thread-safe C bridge.
- AVKit/AVPlayer HLS playback, iOS inline/full-screen playback, Apple TV full-screen playback and remote Back/Menu handling.
- Apple channel search, group filters, favorites/history, now/next and channel schedules with background XMLTV imports and short-guide fallback.
- Keychain account storage, explicit simulator-only local credential injection, native icons and privacy manifest.
- Shared Xcode schemes, automatic signing configuration, TestFlight export options and Xcode Cloud Rust setup scripts.

### Changed

- Xtream supports separate HLS and MPEG-TS URLs for native Apple and Windows playback.
- Apple catalog imports commit the namespace and guide invalidation atomically; stale account responses cannot restore a disconnected account.
- Ignore the extensionless local credential file and Apple build/user artifacts.

## [0.1.0] - 2026-09-30

### Fixed

- Keep Windows playback stop, channel switching and VLC shutdown off the UI thread; preserve the native window message pump during cleanup.
- Order stop requests with channel selections so delayed playback requests cannot restart a stopped stream.

### Added
- Initial Windows desktop IPTV app with the dark Cinema interface, embedded VLC playback and fullscreen controls.
- Portable Rust core with M3U/M3U Plus and XMLTV parsers, Xtream account/channel/EPG support and SQLite persistence.
- Channel groups, Unicode-aware search, paginated browsing, favorites and viewing history.
- Now/next, upcoming programmes and a horizontal TV Guide in local time.
- Windows Credential Manager integration, native-only development credential loading and credential-safe error handling.
- Streaming large-guide imports, bounded resource use, cached-library recovery and on-demand short EPG.
- Windows NSIS packaging with the VLC runtime, documentation and automated verification.
