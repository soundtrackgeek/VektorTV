# Verification

## Desktop and Apple release — 0.4.0

Checks on 2026-10-01: frontend lint/tests and Rust workspace tests/Clippy passed. The redesigned Tauri interface is shared by Windows and macOS. A packaged Mac debug app rendered live NRK1 MPEG-TS video at 1920 × 1080 and passed pause/resume, mute/unmute and Cmd-Q shutdown. Final release packaging and platform verification are in progress; results will be recorded below when complete.

Released Xcode 26.6 built both native Apple 0.4.0 (5) archives. App Store Connect accepted the iOS upload at 19:37:48 and tvOS upload at 19:40:25 Europe/Oslo. Processing and VektorTV Internal availability still require confirmation. Native Apple interface behavior is unchanged from the verified 0.3.0 release.

## Native Apple apps — 0.3.0

Local checks on macOS on 2026-10-01, using released Xcode 26.6 (17F113):

- iOS and tvOS Debug simulator builds and Release device archives succeeded for **0.3.0 (4)**. Archive metadata confirms the marketing version and build number on both platforms.
- Apple TV 1080p / tvOS 26.5: all three checked-in XCTest integration tests passed, covering programme-guide/group navigation, fifteen downward and ten upward remote moves with visible-focus assertions, and search/live playback/full-screen return/stop. A final playback rerun also passed favorite toggling twice and restoring the original state.
- iPhone 17 Pro / iOS 26.5: both guide/group and live-playback tests passed. The compact layout keeps the selected video and controls above the channel browser. Full-screen return preserves the selected stream; explicit Stop clears it.
- iPad Pro 11-inch (M5) / iOS 26.5: both tests passed, including real live video, guide/group navigation, favorite round-trip, full-screen return and Stop. The portrait 834 × 1210-point window renders the two-column layout without clipping its controls.
- Source mockup and rendered Apple TV screen were opened together and compared. iPhone and iPad runtime captures were also visually inspected. See [design-qa.md](../design-qa.md) for the final design comparison and intentional adaptations.
- Local test results and captures: `artifacts/cinema-tvos-tests-4.xcresult`, `artifacts/cinema-tvos-playback-final.xcresult`, `artifacts/cinema-ios-tests-3.xcresult`, `artifacts/cinema-ipad-tests.xcresult`; final screenshots `artifacts/cinema-tvos.png`, `artifacts/cinema-iphone.png`, `artifacts/cinema-ipad.png`. These artifacts are ignored by Git.
- Tests use the simulator's explicitly configured local account. No credentials or provider database are included in the app or test sources. Windows code and distribution are unchanged in this Apple interface release.
- Distribution: both **0.3.0 (4)** Release exports/uploads succeeded (iOS at 18:36:39 and tvOS at 18:39:00 Europe/Oslo). Apple completed processing, and both builds were visibly confirmed as **Testing** on the **VektorTV Internal** group Builds page. See [apple-release.md](apple-release.md) for direct build links and local release evidence.

Physical-device playback and audio, Siri Remote hardware, AirPlay, Picture in Picture, accessibility-size/VoiceOver behavior, split-window resizing and long viewing sessions remain unverified.

## Native Apple apps — 0.2.1

Local checks on macOS on 2026-10-01:

- iOS and tvOS Debug simulator builds succeeded for version 0.2.1 (3).
- Reproduced the Apple TV search layout with the cached 54,745-channel catalog: the native inline keyboard and navigation title left only two complete rows visible, and the fallback TV symbol overlapped channel names.
- The revised tvOS browser displays five complete rows plus part of a sixth at 1920 × 1080. Searching for `nrk`, completing the system keyboard with Done and scrolling retain that space; the focused row has a teal outline and readable text. Fallback logos fit within their reserved slots.
- Three XCTest smoke checks passed using a temporary local harness and the simulator's saved account: remote scrolling down fifteen times and back up ten times, focus movement to favorite/info actions, search entry/completion and twelve downward moves through NRK results, and group chooser/TV Guide/schedule navigation with Back/Menu return. Focused controls remained within the viewport bounds during the scrolling checks.
- Released Xcode 26.6 built iOS and tvOS Release device archives for version **0.2.1 (3)**. Both App Store Connect exports/uploads succeeded with automatic distribution signing, completed Apple processing and show **Testing** in **VektorTV Internal**.
- README, changelog, native About text and generated Apple project versions were updated. `AGENTS.md` now requires both TestFlight uploads after every version bump. Physical Apple TV and Siri Remote testing remain unverified.

## Native Apple apps — 0.2.0

Local checks on macOS on 2026-09-30:

- iOS and tvOS simulator builds succeeded. Released Xcode 26.6 built device archives for both platforms, with automatic App Store distribution signing at export.
- Thirteen Rust tests passed, including C-boundary ownership, credential-safe errors, encoded HLS paths, account isolation, disconnect behavior and atomic catalog/guide rollback. Core/bridge Clippy passed with warnings denied; workspace formatting passed.
- The existing frontend's ESLint, two tests, TypeScript check and production Vite build passed. `npm ci` reported zero vulnerabilities.
- Real account import loaded **54,745 channels**. The iOS background XMLTV import cached **428,982 programme records**; now/next and NRK schedules displayed local-time programme details.
- **NOR| NRK1 HD** visibly rendered live video through AVPlayer HLS on the iPhone simulator. Inline playback, full-screen entry/exit, stop, favorite changes and schedule presentation were exercised. Audio was not assessed by listening.
- Reinstall/relaunch restored Keychain credentials and the catalog. The tvOS app also restored its catalog and displayed the native interface. Simulator input automation could not complete tvOS playback/remote verification; these checks require TestFlight testing on an Apple TV.
- A favorite and two history records persisted across iOS rebuild/relaunch. tvOS cached 429,355 guide records.
- Both **0.2.0 (2)** release packages uploaded successfully, completed Apple processing and show **Testing** in the internal TestFlight group. The account holder's invitation is recorded as **Invited**.
- Release apps contain no bundled development account. The ignored local credential file is read only by the explicit simulator launcher; native account credentials stay in Keychain and authenticated stream URLs stay in memory.

Physical-device playback, Siri Remote hardware, AirPlay, Picture in Picture, background behavior, long sessions and all provider codecs/channels remain unverified. See [apple-release.md](apple-release.md) for distribution and device-testing details.

## Windows — 0.1.0

Local checks performed on Windows on 2026-09-30. Credentials were read from the ignored `.env` and saved through Windows Credential Manager. Authenticated URLs and secrets were omitted from logs and artifacts.

## Automated checks

- ESLint with zero warnings, TypeScript checking and the Vite production build passed.
- Two frontend tests passed: programme progress/timeline boundaries and stale-request ordering.
- Rust formatting and Clippy for the entire workspace/all targets passed with warnings denied.
- Nine Rust tests passed: M3U quoting/BOM/duplicates, invalid feeds, Xtream response variants and account-scoped identities, encoded credentials, XMLTV offsets/entities/CDATA/malformed feeds, Unicode/literal-wildcard searches, SQLite restart persistence, programme boundaries and failed-import preservation.
- `npm audit` reported zero vulnerabilities in the installed dependency tree.

## Live service

- Account authentication succeeded; the provider reported an active account and MPEG-TS output support.
- M3U and XMLTV endpoint probes returned HTTP 200 with valid feed headers. Full catalog import used the Xtream API.
- The explicit core live-check example imported **54,745 channels**, **841 groups** and **438,734 matched guide records** into a disposable SQLite database.
- Catalog retrieval took approximately **7.04 seconds**; a 100-row channel query over the imported database took approximately **53.6 ms** in that run.
- The XMLTV source exceeded 128 MiB. The implementation was changed to stream the response through a bounded queue into the parser; the subsequent complete import succeeded.
- The native app completed its own catalog/guide import. Real NRK channel now/next information and upcoming local-time schedules were inspected.

## Interface and native playback

- Browser preview checked at 1440 × 900 and 1024 × 680: navigation, favorites, channel search, group filtering, empty results, guide and Settings. At the minimum viewport, document width/height matched the viewport; no page-level horizontal overflow was present.
- Browser console inspection after the final reload reported zero errors and warnings. Browser data is explicitly illustrative and cannot connect to the service or play streams.
- Real NRK1 MPEG-TS video was visibly rendered by embedded VLC at **1920 × 1080** in both the debug application and installed release.
- Pause, resume, mute/unmute and fullscreen/escape were exercised in the native application. Mute was verified through the native volume value; audio was not assessed by listening.
- The first stop test revealed a Windows UI-thread stall. Playback operations and shutdown were moved off the window thread; the installed release then returned to **Ready** after Stop with working navigation.
- A favorite and decoded-playback history created in the debug app were present in the installed release after restart. History is recorded only after native decoder statistics show decoded video or audio.
- Switching from NRK1 HD to NRK2 HD produced visible video at 1920 × 1080 with the second channel's programme details. Closing the installed app during playback completed VLC cleanup and terminated the process successfully.

## Packaging

- `npm run bundle` produced `target/release/bundle/nsis/VektorTV_0.1.0_x64-setup.exe` (approximately 39.89 MiB), with VLC DLLs/plugins and original license notices.
- Silent NSIS installation exited successfully to `%LOCALAPPDATA%/VektorTV`.
- Both the built and installed executable were verified as PE subsystem **2 (Windows GUI)**.
- The installed app launched with the Vite server stopped and restored its saved connection, library, favorite and history.

## Coverage limits

This is local Windows verification, not a complete provider/channel/codec matrix. HLS, every channel variant, prolonged playback, provider outages, Windows 10, another clean Windows machine and installer upgrade/uninstall are not separately verified. The installer is unsigned. Native Apple verification is recorded above.

Preview screenshots are generated under ignored `artifacts/`; they use illustrative data. The source tree contains no provider credentials, databases, VLC binaries or generated installer.
