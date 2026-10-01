# VektorTV

A personal IPTV player for **Windows 11 (64-bit), macOS 12+, iOS/iPadOS 18+ and tvOS 18+**. Windows and Mac use Tauri 2 and React/TypeScript; Apple devices use native SwiftUI and AVKit/AVPlayer. Both share the portable Rust core. The Cinema interface puts live video first: a dark viewing room, teal accents, a compact channel browser and a programme guide.

## Features in 0.4.0

The Tauri desktop client includes:

- Xtream account login or an HTTP M3U/M3U Plus playlist, with optional XMLTV guide.
- Embedded VLC playback, including MPEG-TS and HLS, with pause/resume, stop, volume and fullscreen.
- Search and group filtering, paginated channel browsing, persistent favorites and viewing history.
- Now/next programmes, upcoming schedules and a three-hour EPG grid. All programme times display in the computer's local time.
- SQLite metadata cache; successful channel imports become available while the guide continues loading. A failed import retains the previous snapshot.
- Streaming XMLTV parsing with a bounded network queue. Guide imports retain six hours of past programmes and the next 48 hours; a 1 GiB input limit and 384 MiB matched-data working-set limit protect the app from excessively large feeds.
- On-demand Xtream short EPG for a selected channel while the main guide is unavailable or still importing.
- Windows Credential Manager or macOS Keychain protects the saved connection. Credentials and playback URLs are not stored in SQLite or browser storage.
- Window size/position, selected section and channel group survive restart. Playback starts only when a channel is chosen.
- Playback stop, switching and shutdown run away from the native UI thread so VLC can finish native video cleanup without freezing the window.

The Cinema Lounge design is shared across desktop and native Apple: Watch/TV Guide navigation, a restrained charcoal/teal palette, real channel identities, a 16:9 viewing surface and programme details. Desktop keeps searchable groups, paginated lists, keyboard shortcuts and playback controls outside the native video surface.

The native Apple apps add HLS live playback, channel search/group filters, favorites/history, now/next and channel schedules. The Cinema Lounge interface gives Apple TV and wider iPad windows a channel sidebar beside a 16:9 inline player and programme details; compact iPhone/iPad windows stack the player with the channel list. Channel names and logos remain visible, with a white remote-focus outline separate from the teal playing-channel marker. Accounts are saved in Keychain. Apple TV metadata lives in its purgeable cache; favorites/history survive ordinary restarts but tvOS may reclaim that cache. A provider must supply streams/codecs AVPlayer supports; desktop VLC supports additional formats.

The app supplies no channels or subscription. Use your own authorized service. Movies/VOD, series, recording, catch-up, multiple providers and cross-device sync are future work.

## Run the native Apple apps

Open `apps/apple/VektorTV.xcodeproj` in Xcode 26.6 or newer. Choose **VektorTV-iOS** for iPhone/iPad or **VektorTV-tvOS** for Apple TV. Install the pinned Apple build toolchain first:

```sh
rustup toolchain install 1.98.1 --profile minimal
rustup target add --toolchain 1.98.1 aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-tvos aarch64-apple-tvos-sim
open apps/apple/VektorTV.xcodeproj
```

The Xcode build phase compiles `vektortv-apple` and links it into each native target. No Tauri webview, VLC, Node.js, XcodeGen or generated Swift bindings are needed. Regenerate the checked-in project or icon assets with `python3 apps/apple/scripts/generate-project.py` or `python3 apps/apple/scripts/generate-assets.py`.

On first launch, enter your Xtream account in **Settings**; the server defaults to `http://ourxtream.com`. **Connect & load channels** imports the catalog before loading the guide in the background. Search and **All groups** narrow the channel list; **All channels** switches to Favorites or Recently watched. Select a channel to watch inline, then use **Full screen** to expand the picture. Back/Menu on Apple TV and Close on iPhone/iPad return to the viewing room while playback continues; **Stop playback** ends the stream. The programme area has favorite, schedule and stop actions. Long-press a channel for its favorite and schedule menu. **TV Guide** shows channel schedules, and the playing-channel bar returns to Watch.

On Apple TV, select **Find a channel** in the channel sidebar to open the system keyboard, then choose **Done** to browse results using the available screen height. The focused channel row has a white outline and stays visible when moving up/down. The playing channel keeps its separate teal marker. **Clear channel search** restores the full list; changing search, group or library section starts at the top.

After building/installing a Debug app on a booted simulator, explicitly inject the local development account:

```sh
python3 apps/apple/scripts/run-development.py <simulator-UDID>
```

This reads the ignored `.env` (or the existing extensionless `env` file) and passes credentials through the simulator process environment. Release apps ignore development account injection and never bundle account values. Keep simulator signing enabled when testing Keychain.

See [docs/apple-release.md](docs/apple-release.md) for archive/upload commands and TestFlight/Xcode Cloud setup.

Every version bump must include Release archives and TestFlight uploads for both native Apple apps, followed by verification that the builds are available in **VektorTV Internal**. This release requirement is recorded in [AGENTS.md](AGENTS.md).

The shared schemes include XCTest UI integration tests. Configure the simulator account with the development launcher first, then run `xcodebuild -project apps/apple/VektorTV.xcodeproj -scheme VektorTV-iOS -destination 'platform=iOS Simulator,id=<simulator-udid>' -parallel-testing-enabled NO test`; use scheme `VektorTV-tvOS` and platform `tvOS Simulator` for Apple TV. Tests skip without a configured account and require the test provider's NRK1 channel for live playback. They restore the favorite state after checking it. Current results and coverage limits are in [docs/verification.md](docs/verification.md).

The iOS and tvOS **0.3.0 (4)** builds are available in the **VektorTV Internal** TestFlight group. Both completed Apple processing and show **Testing** on 2026-10-01. [TestFlight builds](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/groups/ee71aad3-175f-47d8-bac5-d0c32917045a/builds). Enter your own IPTV credentials on each device. Release evidence is recorded in [docs/apple-release.md](docs/apple-release.md). Xcode Cloud scripts are included for future workflow setup; builds are uploaded locally.

## Run the desktop app

### Windows 11

Requirements: Node.js 22+, Rust stable with the MSVC toolchain, Visual Studio C++ Build Tools and Windows WebView2. Install 64-bit VLC 3 from [VideoLAN](https://www.videolan.org/vlc/) for development; installer builds include the prepared runtime.

```powershell
npm ci
npm run prepare:vlc
npm run desktop
```

### macOS

Requirements: Node.js 22+, Rust stable, Xcode Command Line Tools and VLC 3 matching your Mac's architecture. Install VLC from [VideoLAN](https://www.videolan.org/vlc/) into `/Applications` or `~/Applications`.

```sh
npm ci
npm run prepare:vlc:mac
npm run desktop
```

Mac uses a native AppKit video view with libVLC, WKWebView for the interface and Keychain for credentials. The bundled app includes VLC, so recipients do not need a separate VLC installation. The local Apple Silicon build is tested; Intel Macs need a separate x86_64 build with x86_64 VLC. Windows builds need the Windows toolchain and VLC DLLs; do not reuse a prepared runtime across platforms.

### Connect and watch

Open **Settings**, choose Xtream or M3U, enter the service details and select **Connect & load channels**. Xtream uses a base server address such as `http://provider.example:8080`; do not enter `get.php` as the server address. Its XMLTV endpoint is inferred unless an override is supplied.

For M3U Plus, the usual query structure is `get.php?username=...&password=...&type=m3u_plus&output=ts`. The guide structure is `xmltv.php?username=...&password=...`.

### Local development credentials

Copy `.env.example` to `.env` and set `iptv_username`, `iptv_password` and optionally `iptv_url`. Only the **debug Tauri application**, the explicit Apple simulator launcher and the explicitly invoked live-check example read this file. Debug first launch saves it in the platform credential store if no saved connection exists. Release desktop applications use the platform credential store or the Settings form; `.env` is never packaged.

Do not prefix secrets with `VITE_`. `.env`, generated runtime files, local databases, screenshots and build artifacts are ignored by Git. Errors deliberately omit authenticated provider URLs.

```powershell
# Explicit, read-only provider check; uses a disposable database, prints only counts/timings.
cargo run -p vektortv-core --example service_check
```

### Interface preview

```powershell
npm run dev
```

Open `http://127.0.0.1:1437/?demo=1` for **illustrative interface data**. A browser preview cannot access the saved account or play IPTV streams. The native app uses real commands and service data.

Keyboard: `Ctrl K` on Windows or `Cmd K` on Mac searches, `Space` pauses/resumes outside form controls, `F` toggles fullscreen and `Esc` exits fullscreen. The native playback controls remain below the video surface so they stay clickable.

## Checks and packaging

```powershell
npm run lint -- --max-warnings 0
npm test
npm run build
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace

# Release executable (uses a sibling vlc/ runtime or the installed 64-bit VLC).
npm run tauri -- build --no-bundle

# NSIS installer including prepared VLC libraries/plugins and their license notices.
npm run bundle:windows

# macOS .app and .dmg with VLC libraries/plugins and license notices.
npm run bundle:mac
```

With this Cargo workspace, the release executable is `target/release/vektortv.exe`; the installer is under `target/release/bundle/nsis/`. Build files are intentionally not committed. The Windows installer is unsigned. Mac output is `target/release/bundle/macos/VektorTV.app` and `target/release/bundle/dmg/`; local builds use ad-hoc signing and are not notarized. Public Mac distribution needs Developer ID signing and notarization. Automatic updates are not configured. CI builds both desktop packages and publishes them as workflow artifacts.

`scripts/prepare-vlc.ps1` copies the local VLC installation into an ignored resource directory without downloading or changing the installed VLC. Pass `-VlcDirectory` to use another 64-bit installation. VLC libraries/plugins remain governed by their own licenses; their original notices are included with the runtime. `scripts/prepare-vlc-macos.sh` copies the installed Mac runtime and downloads the matching installed VLC version’s license notices. Pass the VLC `.app` path to use another installation. The hardened Mac app permits loading VideoLAN-signed libraries through its library-validation entitlement; runtime libraries are loaded only from explicit bundle/install paths. See [THIRD_PARTY.md](THIRD_PARTY.md).

## Shared architecture

```text
crates/vektortv-core     Domain models, M3U/XMLTV parsing, Xtream clients,
                       Unicode-aware search, favorites/history and SQLite
         |
src-tauri               Windows/macOS shell, keyring, commands, embedded libVLC
         |
src                     React/TypeScript interface
```

The shared core has no Tauri, Win32, UI or playback-engine dependencies. Native platform shells own credentials and playback; the core owns metadata and business logic. Sensitive M3U stream locations remain in an in-memory map. Xtream playback locations are constructed on demand from the keyring-held connection. Stable channel IDs are scoped to the service/account to avoid collisions when switching providers.

`crates/vektortv-apple` exposes a narrow, owned-JSON C ABI to `apps/apple`, which contains the SwiftUI shells, Keychain storage and AVPlayer playback. Calls run on background queues. Rust locks SQLite only during metadata operations; guide downloads do not hold the library lock. Account namespaces and channel imports commit atomically, and account changes invalidate pending guide/playlist responses. Xtream stream URLs are constructed as `.m3u8` for Apple and `.ts` for desktop VLC. M3U stream URLs are used as supplied; incompatible streams show a retryable playback error.

See [docs/app-brief.md](docs/app-brief.md), [docs/design/direction.md](docs/design/direction.md) and [docs/verification.md](docs/verification.md).
