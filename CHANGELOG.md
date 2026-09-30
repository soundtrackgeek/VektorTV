# Changelog

All notable changes are recorded here. Versions follow semantic versioning.

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
