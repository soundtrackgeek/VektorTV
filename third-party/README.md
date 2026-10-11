# Bundled country assets

- SVG flags: [flag-icons 7.5.0](https://github.com/lipis/flag-icons), MIT. Original notices in `flag-icons-LICENSE`. Bundled locally in `public/flags` and compiled as vector image assets for Apple in `apps/apple/Resources/Flags.xcassets`.
- English country names and ISO codes: [i18n-iso-countries 7.14.0](https://github.com/michaelwittig/node-i18n-iso-countries), MIT. Original notices in `i18n-iso-countries-LICENSE`. The shared catalog adds documented IPTV spelling aliases and Kosovo.

No flag service, network lookup or emoji font is required at runtime. Keep both copies of each SVG identical when updating.

## Native Apple playback fallback

Both Apple apps embed the unmodified, dynamically linked **VLCKit 4.0.0-a25** from [VideoLAN's official repository](https://github.com/videolan/vlckit/tree/4.0.0-a25), source revision `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`. VideoLAN's [official binary artifact](https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260929-1631.zip) is checksum-pinned by the package. The framework and its LGPL 2.1 license are shipped in each Apple app; the original notice is `apps/apple/Resources/VLCKit-LICENSE.txt`. Corresponding source, bundled libVLC source references and build/packaging instructions are available in that exact upstream tag. No framework modifications are applied. This prerelease is pinned because VideoLAN's official unified Swift package is on the 4.0 line.

Desktop continues to package VLC 3 through the existing platform scripts; it does not consume the Apple Swift package.
