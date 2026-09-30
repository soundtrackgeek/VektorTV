# VektorTV

A personal IPTV player for **Windows 10/11 (64-bit)**, built with Tauri 2, React/TypeScript and a portable Rust core. The Cinema interface puts live video first: a dark viewing room, teal accents, a compact channel browser and a programme guide.

## Features in 0.1.0

- Xtream account login or an HTTP M3U/M3U Plus playlist, with optional XMLTV guide.
- Embedded VLC playback, including MPEG-TS and HLS, with pause/resume, stop, volume and fullscreen.
- Search and group filtering, paginated channel browsing, persistent favorites and viewing history.
- Now/next programmes, upcoming schedules and a three-hour EPG grid. All programme times display in the computer's local time.
- SQLite metadata cache; successful channel imports become available while the guide continues loading. A failed import retains the previous snapshot.
- Streaming XMLTV parsing with a bounded network queue. Guide imports retain six hours of past programmes and the next 48 hours; a 1 GiB input limit and 384 MiB matched-data working-set limit protect the app from excessively large feeds.
- On-demand Xtream short EPG for a selected channel while the main guide is unavailable or still importing.
- Windows Credential Manager protects the saved connection. Credentials and playback URLs are not stored in SQLite or browser storage.
- Window size/position, selected section and channel group survive restart. Playback starts only when a channel is chosen.
- Playback stop, switching and shutdown run away from the Windows UI thread so VLC can finish native video cleanup without freezing the window.

The app supplies no channels or subscription. Use your own authorized service. Movies/VOD, series, recording, catch-up, multiple providers, cross-device sync and the native Apple apps are future work.

## Run the Windows app

Requirements: Node.js 22+, Rust stable with the MSVC toolchain, Visual Studio C++ Build Tools and Windows WebView2. Install 64-bit VLC 3 from [VideoLAN](https://www.videolan.org/vlc/) for development; installer builds include the prepared runtime.

```powershell
npm ci
npm run prepare:vlc
npm run desktop
```

Open **Settings**, choose Xtream or M3U, enter the service details and select **Connect & load channels**. Xtream uses a base server address such as `http://provider.example:8080`; do not enter `get.php` as the server address. Its XMLTV endpoint is inferred unless an override is supplied.

For M3U Plus, the usual query structure is `get.php?username=...&password=...&type=m3u_plus&output=ts`. The guide structure is `xmltv.php?username=...&password=...`.

### Local development credentials

Copy `.env.example` to `.env` and set `iptv_username`, `iptv_password` and optionally `iptv_url`. Only the **debug native application** and the explicitly invoked live-check example read this file. Debug first launch saves it in Windows Credential Manager if no saved connection exists. Release applications use Credential Manager or the Settings form; `.env` is never packaged.

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

Keyboard: `Ctrl K` searches, `Space` pauses/resumes outside form controls, `F` toggles fullscreen and `Esc` exits fullscreen. The native playback controls remain below the video surface so they stay clickable.

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
npm run bundle
```

With this Cargo workspace, the release executable is `target/release/vektortv.exe`; the installer is under `target/release/bundle/nsis/`. Build files are intentionally not committed. The installer is unsigned; code signing and automatic updates are not configured.

`scripts/prepare-vlc.ps1` copies the local VLC installation into an ignored resource directory without downloading or changing the installed VLC. Pass `-VlcDirectory` to use another 64-bit installation. VLC libraries/plugins remain governed by their own licenses; their original notices are included with the runtime. See [THIRD_PARTY.md](THIRD_PARTY.md).

## Architecture and the Apple roadmap

```text
crates/vektortv-core     Domain models, M3U/XMLTV parsing, Xtream clients,
                       Unicode-aware search, favorites/history and SQLite
         |
src-tauri               Windows shell, keyring, commands, embedded libVLC
         |
src                     React/TypeScript interface
```

The shared core has no Tauri, Win32, UI or playback-engine dependencies. Native platform shells own credentials and playback; the core owns metadata and business logic. Sensitive M3U stream locations remain in an in-memory map. Xtream playback locations are constructed on demand from the keyring-held connection. Stable channel IDs are scoped to the service/account to avoid collisions when switching providers.

On the Mac, retain this crate and introduce a Swift-friendly FFI layer (for example UniFFI or a narrow C ABI), then build native SwiftUI iOS and tvOS interfaces using AVKit/AVPlayer. No Apple app, FFI binding or Apple-device playback is implemented or verified in this Windows release. Apple's supported stream formats will need testing independently of Windows VLC playback.

See [docs/app-brief.md](docs/app-brief.md), [docs/design/direction.md](docs/design/direction.md) and [docs/verification.md](docs/verification.md).
