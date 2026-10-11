# Changelog

All notable changes are recorded here. Versions follow semantic versioning.

## [0.10.2] - 2026-10-11

### Fixed

- Prevent iOS/iPadOS and Apple TV crashes when switching away from, stopping or failing an active VLC fallback stream. Deliver VLCKit events asynchronously on the main queue so player destruction cannot re-enter the decoder's held lock.
- Add a provider-independent active VLC playback/teardown regression and opt-in Discovery History/DMAX-to-NRK switching checks.
- Keep the compact iPhone player and browser controls outside the lazy channel rows to prevent a SwiftUI layout stall when scrolling back to search during playback.

### Changed

- Align all app versions at 0.10.2; increment the Apple build to 15. Desktop uses libVLC directly and does not share the VLCKit callback failure.

## [0.10.1] - 2026-10-11

### Fixed

- Prevent Apple TV native fullscreen channel-swiping crashes by returning AVKit's next/previous completion handlers to the main actor after asynchronous channel lookup and stream startup.
- Add a tvOS callback regression covering both directions and successful/failed transitions after suspension. The 0.10.0 handlers fail all four main-thread assertions; the corrected handlers pass.

### Changed

- Align all app versions at 0.10.1; increment the Apple build to 14. Desktop scoped zapping behavior is unchanged by this tvOS-specific fix.

## [0.10.0] - 2026-10-11

### Added

- Apple TV left/right remote channel zapping in fullscreen, using native AVKit channel flipping and equivalent VLC fallback gestures.
- Previous/Next channel buttons on iPhone, iPad, Apple TV, Windows and macOS; desktop Page Up/Down and fullscreen/popout left/right keyboard shortcuts.

### Changed

- Retain the category, country, search, Favorites or Recently watched scope when selecting a channel. Zapping follows its order across all pages and wraps within that scope; rapid requests advance from the previously requested channel.
- Share scoped neighbour lookup in the Rust core across native Apple and Tauri desktop apps; preserve the scope through Retry and fullscreen/popout, and clear it on Stop.
- Align all app versions at 0.10.0; increment the Apple build to 13.

## [0.9.0] - 2026-10-11

### Added

- A Favorites shortcut in the top bar on Windows, macOS, iPhone, iPad and Apple TV, opening all saved channels without leftover search/group/country filters.
- Persistent Favorite channel order in the shared core, with automatic migration of existing favorites and new favorites appended at the end.
- Hold-and-release arrangement: desktop pointer preview and single-click drop, Apple TV remote up/down and Select to drop, and touch/keyboard move controls with Drop and Cancel.

### Changed

- Favorites keep their saved order through filtering, pagination, catalog refreshes and restarts. Relative moves preserve favorites outside the visible subset and do not tune a channel.
- Keep loaded channel pages after arranging; support edge scrolling and explicit loading for longer lists.
- Align desktop and native Apple versions at 0.9.0; increment the Apple build to 12. iPhone/iPad use touch move controls instead of desktop pointer hover.

## [0.8.0] - 2026-10-11

### Added

- Automatic VLCKit fallback on iOS/iPadOS and tvOS for streams AVPlayer cannot play, including live H.264 streams with MP2 audio and direct MPEG-TS. Retain inline/fullscreen switching, stop and remote pause/resume.
- Pin VideoLAN's official Swift package and artifact checksum; bundle its LGPL notices in both Apple apps.

### Fixed

- Detect ended/empty provider HLS responses before tuning Xtream live channels on Apple, Windows and macOS, even when HTTP 200 or a `.ts` address disguises an offline clip. Show a provider-unavailable message instead of black, silent LIVE playback.
- Require decoded output before LIVE and viewing history, and report prolonged startup/playback stalls across Apple and desktop players.
- Stop the previous desktop channel before stream preflight and retain request ordering during rapid channel changes.

### Changed

- Align desktop and native Apple versions at 0.8.0; increment the Apple build to 11. AVPlayer retains native AVKit integration; fallback fullscreen uses app controls without AVKit Picture in Picture/AirPlay.
- Exclude downloaded Apple build/package files from frontend lint.

## [0.7.0] - 2026-10-01

### Added

- Popout player mode on Windows and macOS: a compact video window with native dragging/resizing, playback controls and a Return to app action that restores the previous window geometry without restarting the stream.
- A Keep on top toggle for desktop viewing, with a visible pressed state and native operating-system window stacking.

### Changed

- Keep fullscreen, Escape, playback errors and native video sizing working in the compact desktop layout.
- Recover the browsing window geometry after quitting in popout, including native macOS termination that bypasses the normal shutdown callback.
- Align desktop and native Apple versions at 0.7.0; increment the Apple build to 10. Native iOS/iPadOS/tvOS playback layouts remain unchanged because desktop window controls do not apply to those platforms.

## [0.6.1] - 2026-10-01

### Fixed

- Load missing, stale or expired full guides automatically on startup and resume across Windows, macOS, iPhone, iPad and Apple TV, independently of channel-cache age and channel playback.
- Check guide freshness during long sessions, throttle automatic retries, and refresh visible schedules/search results after a background import.
- Preserve cached schedules and their search index when a provider returns no matching programmes; show the import failure instead of treating an empty guide as fresh.
- Show background guide loading and failures in native Apple navigation and programme search.

### Changed

- Align desktop and native Apple versions at 0.6.1; increment the Apple build to 9.

## [0.6.0] - 2026-10-01

### Added

- Global programme search on Windows, macOS, iPhone, iPad and Apple TV across all imported guides, with time, country, provider-group and favorite-channel filters.
- A shared SQLite full-text index with case/accent-insensitive word-prefix matching, automatic cached-guide migration and transactional index maintenance.
- Double-click desktop guide programmes and search results to tune live; Apple touch/remote selection offers the corresponding playback action.

### Changed

- Replace eight-channel desktop guide pages with a virtualized scrolling list, automatic channel loading and a sticky time ruler. Native Apple guide lists also load more channels while scrolling.
- Read desktop grid schedules in bounded cache batches, avoiding provider-request bursts while browsing.
- Keep the guide details area stable so selecting a programme cannot move it between double-clicks.
- Route the desktop header search and Cmd/Ctrl-K to programme search while in TV Guide.
- Align desktop and native Apple versions at 0.6.0; increment the Apple build to 7.

## [0.5.0] - 2026-10-01

### Added

- Dedicated Countries navigation on iPhone, iPad, Apple TV, Windows and macOS with bundled SVG flags and country-name boxes.
- Persistent favorite countries pinned above the alphabetical country list, independent of channel favorites.
- Country detail with provider groups and an All channels A–Z action that sorts the entire country before pagination.
- Shared country detection with country-name aliases, leading ISO/provider codes and an International & unassigned fallback for ambiguous or regional groups.
- Automatic country indexing for existing cached libraries, plus regression coverage for migration, persistence, country filtering and alphabetical pagination.

### Changed

- Keep channel search, favorites, history, group filtering and playback available within a visible, clearable country scope.
- Align native Apple and desktop versions at 0.5.0; increment the Apple build to 6.

## [0.4.0] - 2026-10-01

### Added

- Tauri 2 support for macOS: embedded AppKit/libVLC playback, Keychain storage, native keyboard handling, app icon and bundled app/disk-image packaging.
- Windows installer and macOS package builds in CI, with downloadable workflow artifacts.
- Explicit AGENTS.md requirements to keep native Apple and Tauri Windows/macOS experiences aligned when UI, shared features or core behavior changes.

### Changed

- Bring the Cinema Lounge design to both desktop platforms: Watch/TV Guide header, channel sidebar, restrained charcoal/teal styling, 16:9 video and now/next programme details.
- Retain desktop channel search/groups, favorites/history, guide, settings and playback shortcuts in the refreshed layout.
- Keep native playback teardown off the UI thread, including macOS Cmd-Q.
- Synchronize application versions at 0.4.0; native iOS/tvOS distribution uses build 5.

## [0.3.0] - 2026-10-01

### Added

- Cinema Lounge viewing room for native Apple apps, with a channel sidebar and 16:9 inline live video on Apple TV and wide iPad windows, plus a stacked layout on compact screens.
- Current programme details, live progress, next programme and playback actions beside the channel browser; channel context menus retain favorite and schedule access.
- Search within channel groups and a playing-channel bar in the programme guide.
- Checked-in iOS/tvOS UI integration targets for guide/group navigation, live playback, favorites, full-screen return and remote focus scrolling.

### Changed

- Preserve channel names and logos in quieter list rows; distinguish white remote focus from the teal currently playing marker.
- Enter full screen explicitly and return to browsing without stopping playback. Stop remains an explicit playback action.
- Use the native bundle version in About, and release iOS/tvOS version 0.3.0 (4) to VektorTV Internal TestFlight.

## [0.2.1] - 2026-10-01

### Fixed

- Apple TV channel search and browsing use the available screen height with a compact header and an on-demand system keyboard, replacing the oversized search/title area that left only two or three rows visible.
- Keep the focused channel row visible while scrolling in either direction and moving between playback, favorite and programme-guide actions; highlight the full row.
- Scale the fallback TV logo to fit its reserved space so it cannot overlap channel names.
- Start channel lists at the top when changing search, group or library section.

### Changed

- Require Release archives and TestFlight uploads for both native Apple apps after every version bump, with confirmed processing and availability in the internal testing group.

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
