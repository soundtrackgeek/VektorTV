# Cinema Lounge direction

On 2026-10-01 the user selected their generated VektorTV mockup and authorized implementation with the reviewed refinements: real channel identity, source-correct video proportions, catalog search/group access and TV readability.

The visual target uses a graphite viewing room, restrained teal accents, compact navigation, a channel column and a generous live picture above programme details. The native Apple implementation uses SwiftUI, SF Symbols and a real AVPlayer surface. The landscape in the concept represents live video; it is not bundled artwork or a promised programme-art service.

Apple TV and wider iPad windows use a two-column workspace. Compact windows stack player content and channels. Channel names and logos remain visible. White outlines mark remote focus while teal marks active playback; moving focus never starts a stream. Search opens the system editor on Apple TV, and groups remain searchable. Selecting a channel starts inline playback. Full screen is explicit, and Back returns to browsing without stopping the stream.

The programme area supports missing guide data, loading, stream failures, retry, favorites, full schedule and stop. Programme progress is read-only. No VOD, catch-up, recording, recommendation service or additional provider features are implied.

The Windows implementation retains its existing Cinema layout and native VLC integration in this release. Native Apple verification and distribution status are recorded in ../verification.md and ../apple-release.md.

The supplied reference is preserved at cinema-lounge-reference.png. Device screenshots from verification are stored under ignored artifacts/.
