# Native Apple builds and TestFlight

Project: `apps/apple/VektorTV.xcodeproj`. Shared schemes: **VektorTV-iOS** and **VektorTV-tvOS**. Both use bundle identifier `com.soundtrackgeek.vektortv`, Apple team `3L5769JKCM`, version `0.2.1` and build `3`. [VektorTV in App Store Connect](https://appstoreconnect.apple.com/apps/6817723723) supports both platforms. Rust `1.98.1` provides ARM64 iOS/tvOS device and simulator targets; the core is statically linked.

On 2026-10-01, released Xcode 26.6 built both **0.2.1 (3)** Release archives with the Apple TV channel-browser layout fix. Both uploads succeeded, completed Apple processing and show **Testing** in **VektorTV Internal**.

The internal group has automatic distribution enabled and the account holder invited. Open the invitation in TestFlight on iPhone/iPad or Apple TV; enter your IPTV account in Settings. No provider credentials are included in the uploaded apps. [Internal builds](https://appstoreconnect.apple.com/teams/b1e1e3ed-bd76-448e-bf6c-7211ea008199/apps/6817723723/testflight/groups/ee71aad3-175f-47d8-bac5-d0c32917045a/builds).

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

Simulator builds cover both platforms, real provider catalog/XMLTV imports, and iOS native playback/navigation checks. The tvOS catalog and interface were inspected; simulator input automation could not complete its playback/remote checks. Archives cover device compilation and distribution packaging. Physical iPhone/Apple TV audio/video, Siri Remote hardware, AirPlay, Picture in Picture, background behavior and long viewing sessions still need TestFlight device testing. Provider codecs and HLS availability vary by channel.
