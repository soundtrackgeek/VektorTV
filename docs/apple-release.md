# Native Apple builds and TestFlight

## Desktop popout release — 0.7.0 (10)

Both native Apple **0.7.0 (10)** Release archives succeeded with released Xcode **26.6 (17F113)** on 2026-10-01. Distribution exports/uploads are underway; Apple processing and availability in **VektorTV Internal** are not yet confirmed. Apple app behavior is unchanged; this release aligns versions with the Windows/macOS popout feature.

Archives/exports: `apps/apple/build/0.7.0-10/`. Local logs: `/tmp/vektortv-070-{archive,upload}-{ios,tvos}.log`. Verification status will be updated after distribution completes.

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
