# Native Apple builds and TestFlight

## Active VLC teardown crash fix — 0.10.2 (15)

**0.10.2 (15) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** Released Xcode **26.6 (17F113)** built both Release archives, and manifest/version and playback linkage guards passed. Apple accepted uploads at **19:01:33 iOS** and **19:01:28 tvOS Europe/Oslo** on 2026-10-11. Both completed processing and were visibly verified as **Testing** in the group's Builds page at approximately **19:05 Europe/Oslo**.

| Platform | Version/build | Apple accepted upload (Europe/Oslo) | Distribution status | Build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.10.2 (15) | 2026-10-11 19:01:33 | Testing — VektorTV Internal | [iOS build 15](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/70ce0823-caba-4c1a-8a18-ec138a7439b0) |
| tvOS | 0.10.2 (15) | 2026-10-11 19:01:28 | Testing — VektorTV Internal | [tvOS build 15](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/102bdc25-e529-42a3-a404-88878ce0bfba) |

The physical Apple TV report reproduced at 18:48:33 on 0.10.1 (14) confirms a VLCKit decoder-thread teardown abort. VLC events now dispatch asynchronously to the main queue on iOS/iPadOS and tvOS. The release also keeps the compact player outside lazy channel rows to avoid a layout stall found during iPhone verification. The local active-player teardown regression and live Discovery History/DMAX-to-NRK1 switching tests passed on the relevant simulators. The maintained desktop versions align at 0.10.2; desktop uses libVLC directly and does not share this Objective-C callback ownership path. Audio by listening and the patched physical Apple TV remain unverified; see [verification.md](verification.md) for evidence, desktop checks and provider-audio limits.

Archives/exports: `apps/apple/build/0.10.2-15/`; logs: `/tmp/vektortv-0102-archive-{ios,tvos}.log` and `/tmp/vektortv-0102-upload-{ios,tvos}.log`. Implementation commit `b70adef`; [CI run 38157896725](https://github.com/soundtrackgeek/VektorTV/actions/runs/38157896725) passed all Apple, Windows and macOS jobs, including the hosted callback/active VLC teardown regressions and both desktop packages.

## Apple TV swipe crash fix — 0.10.1 (14)

Both released-Xcode **26.6 (17F113)** Release archives passed version/build and playback linkage checks. Apple accepted uploads of **0.10.1 (14)** at **18:35:04 iOS** and **18:34:34 tvOS Europe/Oslo** on 2026-10-11. Both completed processing and were visibly verified as **Testing in VektorTV Internal** at approximately **18:38 Europe/Oslo**. Archives/exports: `apps/apple/build/0.10.1-14/`; logs: `/tmp/vektortv-0101-archive-{ios,tvos}-final.log` and `/tmp/vektortv-0101-upload-{ios,tvos}.log`.

| Platform | Version/build | Apple accepted upload (Europe/Oslo) | Distribution status | Build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.10.1 (14) | 2026-10-11 18:35:04 | Testing — VektorTV Internal | [iOS build 14](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/48b7f855-0e36-4b19-89e7-4f3d734da005) |
| tvOS | 0.10.1 (14) | 2026-10-11 18:34:34 | Testing — VektorTV Internal | [tvOS build 14](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/bdbea63a-48b3-46b2-a68f-cbc42219033e) |

The physical Apple TV crash at 18:18:44 on 0.10.0 (13), while swiping from NOR| NRK1 NORDNYTT HD to NOR| NRK2 HD, aborted in UIKit while AVKit dismissed its channel interstitial on a background thread. Both delegate completions now return on MainActor. The hosted tvOS regression covers next/previous and success/failure after async suspension; the old handlers failed all four main-thread assertions and the fix passed. [CI run 38155879742](https://github.com/soundtrackgeek/VektorTV/actions/runs/38155879742), commit `98d6038`, passed all Apple, Windows and macOS jobs, including the regression. Desktop runtime evidence and hardware-testing limits are recorded in [verification.md](verification.md).

## Channel zapping release — 0.10.0 (13)

**0.10.0 (13) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group's Builds page was visibly verified as **Testing** for both platforms on 2026-10-11 at approximately **18:16 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both final Release archives; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.10.0 (13) | 2026-10-11 18:09:53 | Testing — VektorTV Internal | [iOS build 13](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/0f36d46f-c742-4a60-becc-31e40707a109) |
| tvOS | 0.10.0 (13) | 2026-10-11 18:09:36 | Testing — VektorTV Internal | [tvOS build 13](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/f71f0f38-6cdb-4750-97fa-3ac2ebcb2939) |

Both archives include scoped channel navigation, native AVKit channel-flipping delegates and the final stable VLC remote surface during startup. Manifest version/build checks and both playback linkage guards passed. Category/search and Favorites zapping tests passed on iPhone, iPad and Apple TV; the tvOS VLC fullscreen test passed repeated right/left input while connecting. Desktop packaging and native Mac verification are recorded in [verification.md](verification.md).

Archives/exports: `apps/apple/build/0.10.0-13/`, including `VektorTV-{iOS,tvOS}-final.xcarchive`. Logs: `/tmp/vektortv-0100-archive-{ios,tvos}-final.log` and `/tmp/vektortv-0100-upload-{ios,tvos}.log`.

## Favorites release — 0.9.0 (12)

**0.9.0 (12) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group's Builds page was visibly verified as **Testing** for both platforms on 2026-10-11 at approximately **17:37 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both final Release archives; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.9.0 (12) | 2026-10-11 17:33:04 | Testing — VektorTV Internal | [iOS build 12](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/c205c13d-c58b-4ce6-9ca5-5dc2de78193d) |
| tvOS | 0.9.0 (12) | 2026-10-11 17:32:39 | Testing — VektorTV Internal | [tvOS build 12](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/0d8e2168-8d29-497d-b10f-6541edb1e027) |

Both archives include the final Favorites shortcut, shared persisted order and touch/remote arrangement. Archive manifests confirm version 0.9.0/build 12 and both playback linkage guards passed. The iPhone, iPad and Apple TV arrangement tests and the final iPhone live playback/fullscreen/return/stop test passed. Desktop packaging and native Mac verification are recorded in [verification.md](verification.md).

Archives/exports: `apps/apple/build/0.9.0-12/`. Logs: `/tmp/vektortv-090-archive-{ios,tvos}-final.log` and `/tmp/vektortv-090-upload-{ios,tvos}.log`.

## Playback compatibility release — 0.8.0 (11)

**0.8.0 (11) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group's Builds page was visibly verified as **Testing** for both platforms on 2026-10-11 at approximately **16:33 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both Release archives; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.8.0 (11) | 2026-10-11 16:25:09 | Testing — VektorTV Internal | [iOS build 11](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/ea6a4731-fc46-4194-afb2-5b45365d9ca7) |
| tvOS | 0.8.0 (11) | 2026-10-11 16:25:06 | Testing — VektorTV Internal | [tvOS build 11](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/e7acf496-940e-4a78-a423-a09fd1fd2241) |

This release adds an automatic VLC fallback for Apple-incompatible streams and shared Xtream offline-stream detection. Both archive manifests confirm version 0.8.0/build 11 and include the final native/shared-core implementation and unmodified dynamic VLCKit framework. The final desktop HLS-status adjustment does not change the Apple archives. The libSystem clock linkage guard passed for both archives.

Archives/exports: `apps/apple/build/0.8.0-11/`. Logs: `/tmp/vektortv-080-{archive,upload}-{ios,tvos}.log`. See [verification.md](verification.md) for provider diagnosis, runtime evidence and platform differences.

## Desktop popout release — 0.7.0 (10)

**0.7.0 (10) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group's Builds page was visibly verified as **Testing** for both platforms on 2026-10-01 at approximately **22:24 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both Release archives; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.7.0 (10) | 2026-10-01 22:13:52 | Testing — VektorTV Internal | [iOS build 10](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/eb302e2f-5912-4e43-96ef-765f59712fad) |
| tvOS | 0.7.0 (10) | 2026-10-01 22:13:29 | Testing — VektorTV Internal | [tvOS build 10](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/45945acf-b4b4-46c2-bfb7-9e9ad4d75815) |

Apple app behavior and the shared Rust core are unchanged; this release aligns versions with the Windows/macOS popout feature. Both archive manifests confirm version 0.7.0/build 10. Later corrections are limited to desktop window lifecycle/geometry recovery and the browser demo version, and do not affect these Apple archives.

Archives/exports: `apps/apple/build/0.7.0-10/`. Local logs: `/tmp/vektortv-070-{archive,upload}-{ios,tvos}.log`. No provider credentials are bundled. See [verification.md](verification.md) for desktop checks and platform limits.

## Automatic guide loading — 0.6.1 (9)

**0.6.1 (9) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group's Builds page was visibly verified as **Testing** for both platforms on 2026-10-01 at approximately **21:55 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both Release archives from the final source; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.6.1 (9) | 2026-10-01 21:51:28 | Testing — VektorTV Internal | [iOS build 9](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/84757195-6788-4609-b8a2-2725891ed526) |
| tvOS | 0.6.1 (9) | 2026-10-01 21:51:06 | Testing — VektorTV Internal | [tvOS build 9](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/fe54e3f1-6f3d-44a9-b793-50521c8ed65e) |

This release refreshes the full searchable guide on startup/resume independently of channel playback, exposes loading/failure status, and retains cached programmes after empty imports. iPhone/iPad/tvOS integration tests passed, including real HLS playback. Fresh iPhone and tvOS launches recovered interrupted full imports to **420,624 cached programmes** each without playback; global search passed again against those full caches. See [verification.md](verification.md).

Archives/exports: `apps/apple/build/0.6.1-9/`. Local logs: `/tmp/vektortv-061-9-{archive,upload}-{ios,tvos}.log`. Both archive manifests confirm version 0.6.1/build 9, and both Settings object files were compiled after the final source adjustment. No provider credentials are bundled. Build 8 also completed processing, but build 9 supersedes it to include the final Settings disabled state during guide loading.

## TV Guide release — 0.6.0 (7)

**0.6.0 (7) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group’s Builds page was visibly verified as **Testing** for both platforms on 2026-10-01 at approximately **21:27 Europe/Oslo**. Released Xcode **26.6 (17F113)** built both Release archives; automatic App Store distribution exports/uploads succeeded and Apple completed processing.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.6.0 (7) | 2026-10-01 21:20:01 | Testing — VektorTV Internal | [iOS build 7](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/974be56f-fe93-49c2-8d90-3e1a592aa136) |
| tvOS | 0.6.0 (7) | 2026-10-01 21:19:43 | Testing — VektorTV Internal | [tvOS build 7](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/de31e4ec-0412-439e-bc16-a4ff80605122) |

This release adds programme search across every imported guide, with time/country/group/favorites filters, indexed search for large caches, programme-to-live playback and automatic loading while scrolling guide channels. Native Apple keeps touch/remote schedule lists; desktop adds a virtualized timeline and double-click tuning. iPhone, iPad and Apple TV integration verification is recorded in [verification.md](verification.md).

Archives/exports: `apps/apple/build/0.6.0-7/`. Local logs: `/tmp/vektortv-060-archive-ios.log`, `/tmp/vektortv-060-archive-tvos.log`, `/tmp/vektortv-060-upload-ios.log`, `/tmp/vektortv-060-upload-tvos.log`. Both archive manifests confirm version 0.6.0/build 7. No provider credentials are bundled.

## Countries release — 0.5.0 (6)

**0.5.0 (6) is available in VektorTV Internal on both iOS/iPadOS and tvOS.** The group’s Builds page was visibly verified as **Testing** for both platforms on 2026-10-01. Both native Apple targets use **0.5.0 (6)**. Released Xcode 26.6 (17F113) built the iOS and tvOS Release archives on 2026-10-01, and both automatic App Store distribution exports/uploads succeeded.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.5.0 (6) | 2026-10-01 20:37:42 | Testing — VektorTV Internal | [iOS build 6](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/66b5925e-158a-44bb-9c19-0b57e3822af3) |
| tvOS | 0.5.0 (6) | 2026-10-01 20:36:39 | Testing — VektorTV Internal | [tvOS build 6](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/b5c515d7-31b9-4a2d-9f65-1d0e6690ae05) |

The release adds country flag tiles, country favorites, provider groups within countries and All channels A–Z across every maintained app. Ten native UI integration checks passed across iPhone, iPad and Apple TV, including real HLS playback and favorite persistence. See [verification.md](verification.md).

Archives/exports: `apps/apple/build/0.5.0-6/`. Local logs: `/tmp/vektortv-050-archive-ios.log`, `/tmp/vektortv-050-archive-tvos.log`, `/tmp/vektortv-050-upload-ios.log`, `/tmp/vektortv-050-upload-tvos.log`. Both archive manifests confirm version 0.5.0/build 6. Apple processing completed and both builds were confirmed available in VektorTV Internal at approximately 20:41 Europe/Oslo.

## Previous released builds

Project: `apps/apple/VektorTV.xcodeproj`. Shared schemes: **VektorTV-iOS** and **VektorTV-tvOS**. Both use bundle identifier `com.soundtrackgeek.vektortv`, Apple team `3L5769JKCM`, version `0.4.0` and build `5`. [VektorTV in App Store Connect](https://appstoreconnect.apple.com/apps/6817723723) supports both platforms. Rust `1.98.1` provides ARM64 iOS/tvOS device and simulator targets; the core is statically linked.

**0.4.0 (5) is available in VektorTV Internal on both platforms.** Released Xcode 26.6 (17F113) built both Release archives on 2026-10-01. Automatic distribution exports/uploads succeeded; Apple completed processing and the internal group's Builds page shows **Testing** for both platforms. This release keeps Apple versioning aligned with the new Tauri Windows/macOS interface; native Apple UI behavior is unchanged from 0.3.0.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.4.0 (5) | 2026-10-01 19:37:48 | Testing — VektorTV Internal | [iOS build 5](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/300b9bab-bb2e-4633-b7a5-02467bd961ff) |
| tvOS | 0.4.0 (5) | 2026-10-01 19:40:25 | Testing — VektorTV Internal | [tvOS build 5](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/8cabbd56-aa65-4e1a-99af-ac5947189aca) |

Archives: `apps/apple/build/0.4.0-5/`. Local logs: `/tmp/vektortv-040-archive-ios.log`, `/tmp/vektortv-040-archive-tvos.log`, `/tmp/vektortv-040-upload-ios.log`, `/tmp/vektortv-040-upload-tvos.log`. Both archives and exports report success. Internal availability was visibly verified at approximately 19:46 Europe/Oslo.

### Previous releases

**0.3.0 (4) is available in VektorTV Internal on both platforms.** On 2026-10-01, released Xcode 26.6 (17F113) built both Release archives. Automatic distribution exports/uploads succeeded, Apple completed processing, and the internal group's Builds page shows **Testing** for both iOS and tvOS.

| Platform | Version / build | Upload accepted (Europe/Oslo) | Internal status | App Store Connect build |
| --- | --- | --- | --- | --- |
| iOS / iPadOS | 0.3.0 (4) | 2026-10-01 18:36:39 | Testing — VektorTV Internal | [iOS build 4](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/ios/154ff450-9a3d-4920-ad9f-94758d0c56fe) |
| tvOS | 0.3.0 (4) | 2026-10-01 18:39:00 | Testing — VektorTV Internal | [tvOS build 4](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/tvos/881f435b-843a-4e6c-96f4-8209d5fc9479) |

Local archives are under `apps/apple/build/0.3.0-4/`. Archive/upload logs are `artifacts/cinema-archive-ios.log`, `artifacts/cinema-archive-tvos.log`, `artifacts/cinema-upload-ios.log` and `artifacts/cinema-upload-tvos.log`. Each archive and export reports success. UI test and visual-review evidence are recorded in [verification.md](verification.md) and [design-qa.md](../design-qa.md).

On 2026-10-01, released Xcode 26.6 built both **0.2.1 (3)** Release archives with the Apple TV channel-browser layout fix. Both uploads succeeded, completed Apple processing and show **Testing** in **VektorTV Internal**.

The internal group has automatic distribution enabled and includes the account holder. Open VektorTV in TestFlight on iPhone/iPad or Apple TV to install or update; enter your IPTV account in Settings. No provider credentials are included in the uploaded apps. [Internal builds](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/groups/ee71aad3-175f-47d8-bac5-d0c32917045a/builds).

## Local distribution

Every version bump requires Release archives and uploads for both platforms, followed by confirmation that Apple has processed the builds and made them available in **VektorTV Internal**. A simulator build alone does not complete the release.

Sign into the team's Apple account in Xcode. Use a released Xcode for uploads. When multiple Xcode versions are installed, prefix each command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` to use the released toolchain (currently Xcode 26.6). Build each archive from the repository root:

```sh
xcodebuild -project apps/apple/VektorTV.xcodeproj -scheme VektorTV-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath apps/apple/build/VektorTV-iOS.xcarchive -allowProvisioningUpdates archive

# Distribution export signs this archive without a registered Apple TV.
xcodebuild -project apps/apple/VektorTV.xcodeproj -scheme VektorTV-tvOS \
  -configuration Release -destination 'generic/platform=tvOS' \
  -archivePath apps/apple/build/VektorTV-tvOS.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

Upload with App Store distribution signing:

```sh
xcodebuild -exportArchive -archivePath apps/apple/build/VektorTV-iOS.xcarchive \
  -exportPath apps/apple/build/upload-iOS \
  -exportOptionsPlist apps/apple/Resources/ExportOptions.plist -allowProvisioningUpdates

xcodebuild -exportArchive -archivePath apps/apple/build/VektorTV-tvOS.xcarchive \
  -exportPath apps/apple/build/upload-tvOS \
  -exportOptionsPlist apps/apple/Resources/ExportOptions.plist -allowProvisioningUpdates
```

Export options use `app-store-connect` with destination `upload`. Credentials come from Xcode's account. Increment `CURRENT_PROJECT_VERSION` in the project generator and regenerate before another build of the same version/platform. Export-compliance metadata declares no non-exempt encryption: Rust TLS provides ordinary HTTPS, with no custom cryptography feature.

## Xcode Cloud

In Xcode, use **Product → Xcode Cloud → Create Workflow** to connect GitHub and this shared project. Configure iOS and tvOS archive actions with distribution preparation **TestFlight and App Store**, then a TestFlight internal-testing postaction. `apps/apple/ci_scripts/ci_post_clone.sh` installs pinned Rust and its targets. The normal build phase compiles the static library; the post-build script provides beta testing notes. No IPTV secrets are needed in the cloud workflow.

Cloud workflows are account-side configuration; committed scripts alone do not activate a workflow. Apple must process uploaded builds before a TestFlight group can use them. External testers require beta review. Apple's references: [custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts), [distribution workflows](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution).

## Provider and account handling

The default provider is `http://ourxtream.com`. User-configured IPTV providers and stream redirects may use HTTP, so the native Info.plist allows HTTP loading. HTTPS still validates certificates. Credentials stay in Keychain; no IPTV account is bundled or logged. The deliberate transport exception supports arbitrary HTTP M3U services and redirects; see [Apple's transport documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowsarbitraryloads).

Apple TV metadata is in purgeable cache. Restart persistence is supported, but storage reclamation can remove it; refresh to recover the catalog. Favorites/history are local to each device. VOD/series, recordings, catch-up and cross-device sync remain future work.

## Verification boundaries

Simulator checks cover iPhone, iPad and Apple TV layouts, real HLS playback, search, programme-guide/group navigation, favorite toggling, full-screen entry/return and explicit stop. Apple TV XCTest remote-navigation checks also keep focus visible through repeated list scrolling. Real provider catalog/XMLTV imports were verified in earlier releases. Archives cover device compilation and distribution packaging. Physical iPhone/Apple TV audio/video, Siri Remote hardware, AirPlay, Picture in Picture, background behavior and long viewing sessions still need TestFlight device testing. Provider codecs and HLS availability vary by channel.
