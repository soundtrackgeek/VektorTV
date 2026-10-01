# Verification

## Automatic guide loading — 0.6.1

Checks on 2026-10-01 on Apple Silicon macOS, using released Xcode 26.6 (17F113):

- Reproduced the reported desktop cache state: a recent channel timestamp, no completed full-guide timestamp, and only **586 short-guide programmes**. Startup previously checked channel age only; native Apple restored the catalog without refreshing its guide. BBC variants already had matching provider EPG IDs.
- **21 Rust tests** passed, including regressions for short-guide entries not hiding a missing full import, stale/expired coverage, clock correction, and empty-import cache/search preservation. Workspace Clippy with warnings denied and formatting passed. Frontend lint with zero warnings, both tests, TypeScript checking and production Vite build passed.
- A real-provider check using a disposable database imported **54,745 channels / 841 groups** and **423,731 matched programmes**. No credentials or stream URLs were printed.
- The packaged **macOS 0.6.1** app automatically started a guide-only import on launch with that incomplete cache, showed progress, and saved **423,543 matched entries / 420,681 unique programmes across 8,689 channels**. The channel timestamp remained unchanged. BBC 1, BBC 1 HD and BBC 1 HEVC each received **52 programmes**; BBC 2, BBC 2 HD and BBC 2 HEVC each received **57**. All six populated without first playing them. Native global search found 139 title/description/category matches for `Question Time`, including channels outside the sidebar's BBC 1/UK scope.
- Native Mac BBC 1 VLC video visibly played at **1720 × 720** after guide verification. Stop worked and returned to the populated BBC 2 guide. Audio was not assessed by listening. Computer control initially timed out while the new app launched; reacquiring the explicit release path succeeded, so this release has fresh native interaction evidence.
- Browser flow: **TV Guide → Search programmes → Ocean Explorers** found the National Geographic result. Playwright CLI checked `http://127.0.0.1:1438/?demo=1` at **1440 × 950** and **402 × 874** (Browser plugin not available). Page identity, meaningful rendering, absence of framework overlays, screenshot review and interactions passed. Final console: **zero warnings/errors**. Screenshots: `/tmp/vektortv-061-preview-{search,mobile}.png`. Browser fixtures are illustrative; native import/playback evidence comes from the packaged app above.
- **Six XCTest integration checks** passed across iPhone 17 Pro, iPad Pro 11-inch (M5) and Apple TV 1080p: global programme search, empty results and filters; real NRK1 HLS playback, favorite round-trip, full-screen return and stop. The iPhone/tvOS test launches interrupted background guide imports; leaving each app open on a subsequent launch recovered **420,624 unique programmes** without playback. The iPhone's prior guide timestamp was stale; tvOS previously held only 32 short-guide entries. Loading status was visually checked on iPhone.
- Local Mac `.app` and ARM64 `.dmg` built; `codesign --verify --deep --strict` passed. Outputs: `target/release/bundle/macos/VektorTV.app` and `target/release/bundle/dmg/VektorTV_0.6.1_aarch64.dmg`.
- [CI run 36915924340](https://github.com/soundtrackgeek/VektorTV/actions/runs/36915924340), implementation commit `254f7be`: all Windows, macOS and Apple jobs passed, including both desktop packages.
- Build 9 is being archived/exported from the final source because build 8 preceded the final Settings disabled-state adjustment. Both Apple **0.6.1 (8)** uploads succeeded (iOS **21:42:24**, tvOS **21:42:36 Europe/Oslo**) and completed processing. Both were visibly confirmed as **Testing** in **VektorTV Internal** at approximately **21:46**. See [apple-release.md](apple-release.md).

Evidence: `/tmp/vektortv-061-{tests,clippy,provider-check,mac-build}.log`, `/tmp/vektortv-061-test-{ios,ipad,tvos}.log` and the corresponding `/tmp/vektortv-061-{ios,ipad,tvos}.xcresult` bundles. Archives/exports are under `apps/apple/build/0.6.1-8/`. Native screenshots were inspected through computer control; these local logs/captures are not committed.

Limits: Windows 11 is unavailable for interactive playback verification in this Mac session. Physical Apple devices, hardware Siri Remote, Intel Mac, macOS 12, audio by listening, accessibility text sizes/VoiceOver and prolonged playback remain unverified. Guide availability still depends on the provider: a full download cannot supply programmes for channels absent from its XMLTV feed. Desktop retains VLC/timeline/mouse input; Apple retains AVPlayer/touch/remote schedules. Mac packages are ad-hoc signed and not notarized; Windows packages are unsigned.

## TV Guide release — 0.6.0

Checks on 2026-10-01 on Apple Silicon macOS, using released Xcode 26.6 (17F113):

- Frontend lint (zero warnings), both frontend unit tests, TypeScript and production Vite build passed. All **19 Rust core/Apple bridge tests**, workspace Clippy and formatting passed. Search tests cover the complete catalog beyond the first 200 channels, combined filters before pagination, stable page order, time boundaries, case/accent handling, quoted input, removed channels, cache migration/restart, replacement imports and merged-guide updates.
- A disposable copy of the iPhone cache contained **428,982 programmes**. Building its full-text index took **4.84 seconds**; representative searches then took **85–118 ms** in a Debug-linked local benchmark (502 matches, 4,617 matches and no matches). This measures local query performance, not provider download time. Native Apple opens/migrates the cache away from the main actor.
- Browser flow: **TV Guide → scroll → select/double-click → Watch**, then **Search programmes → cross-library result → filters → Watch**. Playwright CLI checked `http://127.0.0.1:1437/?demo=1` at **1440 × 950** and **402 × 874**. Browser plugin was unavailable. Page identity, meaningful content, absence of framework overlays, final console health (zero warnings/errors), screenshots and target interactions passed; compact mode had no document horizontal overflow.
- A disposable 250-channel browser fixture automatically loaded through channel 250, then scrolled back to channel 1 while mounting fewer than 35 guide rows. The time ruler remained visible. Bottom-row double-click worked after reserving stable space for programme details. Search found National Geographic’s **Ocean Explorers** while the sidebar was restricted to Norway; `oce expl` matched both word prefixes. Country, favorites, live-time and empty-result states were exercised. These fixtures cannot prove native VLC playback.
- Native UI integration checks passed across **iPhone 17 Pro, iPad Pro 11-inch (M5) and Apple TV 1080p**, including global search/empty state/filter navigation, channel-guide/group navigation and the existing real NRK1 HLS playback/full-screen/return/favorite/stop flow. The original full-scan search failed the large-cache latency check; the indexed implementation passed its iPhone, iPad and tvOS reruns. iPhone and iPad tested more than 423,000 imported programmes; tvOS used its smaller short-guide cache. Search/filter screens were visually inspected on all three.
- Final local Mac `.app` and ARM64 `.dmg` built, and `codesign --verify --deep --strict` passed. Outputs: `target/release/bundle/macos/VektorTV.app` and `target/release/bundle/dmg/VektorTV_0.6.0_aarch64.dmg`.
- **Native Mac interaction verification is blocked:** the computer-control tool repeatedly returned `Computer Use server error -10005: timeoutReached` while acquiring the release app, including after packaging finished and a fresh launch. The process starts and remains in its AppKit event loop, but this is not proof of visible playback or working native interactions. No fresh 0.6.0 native VLC playback claim is made.
- [CI run 36913379743](https://github.com/soundtrackgeek/VektorTV/actions/runs/36913379743) passed **all Windows, macOS and Apple jobs** for implementation commit `981c0b1`, including frontend/core checks, Windows NSIS installer packaging, Mac disk-image packaging and both Apple simulator builds. The Windows installer is retained locally under `artifacts/desktop-0.6.0-windows/`.
- Both released-Xcode archives report **0.6.0 (7)**. App Store Connect accepted tvOS at **21:19:43** and iOS at **21:20:01 Europe/Oslo**. Both builds completed processing and were visibly verified as **Testing** in **VektorTV Internal** at approximately **21:27 Europe/Oslo**; see [apple-release.md](apple-release.md).

Evidence: `/tmp/vektortv-060-{rust-tests,clippy,mac-final-build}.log`; `/tmp/vektortv-060-test-ios-indexed.log`, `/tmp/vektortv-060-test-ipad-final.log`, `/tmp/vektortv-060-test-tvos-final.log`; corresponding `.xcresult` bundles under `apps/apple/.derivedData/guide-*`; exported captures in `/tmp/vektortv-060-{ios-indexed,ipad-final,tvos}-captures/`; `/tmp/vektortv-guide-{search-final,250,mobile}.png`. Archives and exports are in `apps/apple/build/0.6.0-7/`, with `/tmp/vektortv-060-{archive,upload}-{ios,tvos}.log`. Evidence remains outside version control.

Limits: Windows 11 is unavailable for interactive runtime verification in this Mac session. Physical Apple devices, hardware Siri Remote, Intel Mac, macOS 12, audio by listening, accessibility text sizes/VoiceOver and prolonged playback remain unverified. Mac packages are ad-hoc signed and not notarized; Windows packages are unsigned. Search can only find guide data actually supplied and imported, within the retained time range; old cached schedules may require refresh. Apple uses touch/remote schedule lists and a filter sheet; desktop uses a scrolling timeline, mouse double-click and inline filters.

## Countries — 0.5.0 (6)

Checks on 2026-10-01 on Apple Silicon macOS 26.6.2, using released Xcode 26.6 (17F113):

- All **17 Rust tests** passed, covering provider-prefix ambiguity, country-name matching, cached-library migration, favorite persistence across restart/refresh, country filtering before pagination and case/accent-insensitive alphabetical ordering. Workspace Clippy (warnings denied) and formatting passed.
- Frontend ESLint with zero warnings, both existing frontend tests, TypeScript and the production Vite build passed.
- **10 XCTest UI integration checks** passed: three each on iPhone 17 Pro and iPad Pro 11-inch (M5), both iOS 26.5; four on Apple TV 4K at 1080p, tvOS 26.5. Each platform verified country search/flags, country favorite persistence after termination/relaunch, groups, All channels A–Z and scope clearing. The existing real HLS playback, guide/group navigation, channel favorite round-trip, full-screen return and Stop checks passed. Apple TV also passed repeated remote scrolling with visible-focus assertions.
- Browser preview `http://127.0.0.1:1437/?demo=1` passed at 1440 × 900, 1024 × 680 and 402 × 874. Verified Countries → favorite → reload/pinned favorite → country detail → all channels → group/search filtering, plus empty country search. Country flags loaded, no blank/error overlay appeared, no horizontal document overflow was measured at the smaller viewports, and the console had zero warnings/errors. Browser plugin was unavailable; the Playwright skill/CLI supplied these checks with illustrative data.
- The final packaged **macOS 0.5.0** app restored the saved connection and automatically indexed its cached library into **108 countries plus International & unassigned**. Norway showed **16 groups / 889 channels**. Native country favorite pinning survived Quit/relaunch and was restored to its original state after verification. Country filtering, A–Z browsing and scoped channel search worked.
- Selecting **NOR| NRK1 HD** inside Norway produced visible **1920 × 1080** native VLC video and programme details. Switching to Countries hid the native video surface and displayed a Return to Watch bar; returning preserved LIVE playback. Stop returned to READY. Audio was not assessed by listening.
- All **250 SVG flags** are bundled locally; desktop/Apple source copies are byte-identical. The actual country screens on iPhone, iPad, Apple TV and packaged Mac were visually inspected. Apple compiles the SVGs as vector image assets; Mac/Windows render local SVGs in the webview. Every bundle includes the country asset license notices.
- The final ARM64 Mac app and disk image built; `codesign --verify --deep --strict` passed. Outputs: `target/release/bundle/macos/VektorTV.app` and `target/release/bundle/dmg/VektorTV_0.5.0_aarch64.dmg`.
- [CI run 36907851178](https://github.com/soundtrackgeek/VektorTV/actions/runs/36907851178) passed all three jobs (Windows, macOS and Apple) for implementation commit `c36d1cc`. Windows and macOS checks and packaging succeeded, and both Apple simulator targets built successfully. The Windows installer was downloaded to `artifacts/desktop-0.5.0-windows/VektorTV_0.5.0_x64-setup.exe`.
- Both native Apple Release archives contain **0.5.0 (6)**. App Store Connect accepted tvOS at **20:36:39** and iOS at **20:37:42 Europe/Oslo**. Both completed processing and were visibly verified as **Testing** in **VektorTV Internal** at approximately 20:41 Europe/Oslo; see [apple-release.md](apple-release.md).

Local evidence: `/tmp/vektortv-countries-ios-final-test.log`, `/tmp/vektortv-countries-tvos-final-test.log`, `/tmp/vektortv-countries-ipad-test.log`; `.xcresult` bundles under `apps/apple/.derivedData/countries-{ios,ipad,tvos}/Logs/Test/`; exported UI captures under `/tmp/vektortv-countries-{ios,ipad,tvos}-captures/`; desktop preview captures `/tmp/vektortv-countries-desktop-final.png` and `/tmp/vektortv-countries-mobile.png`. Archives are in `apps/apple/build/0.5.0-6/`; archive/upload logs use `/tmp/vektortv-050-*.log`. These files remain outside version control.

Verification limits: this Mac session cannot interactively run Windows 11, so Windows compilation/packaging must be distinguished from native Windows playback verification. Physical iPhone/Apple TV, hardware Siri Remote, audio by listening, Intel Mac, macOS 12, accessibility text sizes/VoiceOver, every provider/codec and prolonged viewing remain unverified. Country inference depends on recognizable provider group names; unknown and regional groups remain accessible. Mac bundles are ad-hoc signed and not notarized; Windows installers are unsigned.

## Desktop and Apple release — 0.4.0

Checks on 2026-10-01 on Apple Silicon macOS 26.6.2:

- Frontend lint with zero warnings, both frontend tests, TypeScript checking and the production Vite build passed. All thirteen Rust core/Apple bridge tests passed; workspace Clippy and formatting passed.
- [CI run 36901223407](https://github.com/soundtrackgeek/VektorTV/actions/runs/36901223407) passed all Windows, macOS and Apple jobs, including desktop release packaging. The subsequent Mac-only safe-area correction in `5e86ab9` was rebuilt and verified locally in both Debug and Release. The follow-up [CI run 36902214961](https://github.com/soundtrackgeek/VektorTV/actions/runs/36902214961) passed Windows checks/installer packaging and Apple checks; its macOS packaging job was still running when these notes were recorded.
- The in-app browser preview was checked at 1672 × 941 (the source reference dimensions), 1024 × 680 and 402 × 874. Watch/TV Guide navigation, guide programme selection/Watch action, favorites filtering, channel group filtering, empty search, Settings, fullscreen and Escape worked. At the minimum desktop viewport the viewing pane's client and scroll heights both measured 604 pixels; there was no document horizontal overflow. Compact view stacks the picture before the channel browser. Browser console reported zero warnings/errors.
- Packaged native Mac Debug and Release apps rendered real NRK1 MPEG-TS video at 1920 × 1080. Switching to NRK2 also produced visible 1920 × 1080 video. Current and next programme information and eight NRK1 guide entries loaded from the real service.
- Native pause/resume, mute/unmute (volume value 0/80), favorite toggle/restore, guide navigation with video hidden, return to Watch with playback continuing, fullscreen/Escape, explicit Stop/Ready, decoded-playback history, normal window close and Cmd-Q during playback were exercised. Audio was not assessed by listening.
- The initial packaged app could not load VideoLAN-signed libraries under hardened runtime. The explicit library-validation entitlement fixes that integration while retaining hardened runtime. The final release process mapped libVLC, libvlccore and 333 additional runtime files from its own `Contents/Resources/vlc` directory; it did not depend on the separately installed VLC app.
- Native testing found a 32-point Mac title-bar offset. The embedded picture now uses WKWebView coordinates plus its safe-area inset. The final release capture shows the picture aligned with its DOM surface, with programme details and actions below it. See [design-qa.md](../design-qa.md).
- Restarting the release restored the Keychain connection and both history records. Rebuilding with ad-hoc signing prompted for Keychain access; the user approved that protected system dialog directly. No credentials are packaged or printed.
- The final ARM64 release app and DMG built successfully; `codesign --verify --deep --strict` passed. Outputs are `target/release/bundle/macos/VektorTV.app` and `target/release/bundle/dmg/VektorTV_0.4.0_aarch64.dmg`. The Windows installer from CI run 36902214961 was downloaded to `artifacts/desktop-0.4.0-windows-final/VektorTV_0.4.0_x64-setup.exe`. Build artifacts remain ignored by Git.
- Released Xcode 26.6 built both native Apple **0.4.0 (5)** archives. App Store Connect accepted iOS at **19:37:48** and tvOS at **19:40:25 Europe/Oslo**. Apple completed processing and both were visibly confirmed as **Testing** in **VektorTV Internal** at approximately 19:46. Native Apple UI behavior is unchanged from the verified 0.3.0 release. See [apple-release.md](apple-release.md).

Verification limits: Windows compilation, tests and installer packaging passed on the Windows CI runner, but the redesigned 0.4.0 app was not run interactively on Windows 11 in this Mac session. The earlier 0.1.0 Windows runtime results below remain historical evidence. Intel Mac runtime behavior, macOS 12 specifically, audio by listening, multi-monitor DPI changes, all codecs/providers and prolonged playback remain unverified. Mac bundles are ad-hoc signed and not notarized; Windows installers are unsigned.

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
