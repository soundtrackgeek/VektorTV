# Cinema Lounge implementation QA

Date: 2026-10-01. Scope: native Apple interface, version 0.3.0 (4).

**Findings**

No actionable P0/P1/P2 differences remain in the inspected layouts. The implementation retains the reference's charcoal canvas, teal state markers, quiet channel column, large live picture, programme hierarchy and compact Watch/TV Guide navigation.

**Source and rendered evidence**

- Source visual truth: [docs/design/cinema-lounge-reference.png](docs/design/cinema-lounge-reference.png), the user's selected generated mockup, 1672 × 941 pixels. It is an unframed raster concept; native point size and density are unspecified.
- Apple TV: [artifacts/cinema-tvos.png](artifacts/cinema-tvos.png), 1920 × 1080 pixels / points at 1×, captured from the actual tvOS 26.5 app during live playback. The source and this implementation screenshot were opened together in the same comparison input, with their full 16:9 screens fitted to comparable display widths. Comparisons concern composition and readability rather than exact pixel equality.
- iPhone: [artifacts/cinema-iphone.png](artifacts/cinema-iphone.png), 1206 × 2622 pixels, 402 × 874 points at 3×. Inspected as a responsive adaptation; the source does not contain a phone layout.
- iPad: [artifacts/cinema-ipad.png](artifacts/cinema-ipad.png), 1668 × 2420 pixels, 834 × 1210 points at 2×. Inspected as a portrait two-column adaptation. The native status bar and safe areas are included in mobile captures.
- State: dark appearance, authenticated catalog, Watch selected, NRK1 search results, real HLS video with current/next guide data. Source programme names, landscape video and favorite state differ from live runtime data; these are intentional state differences.
- Full-view evidence shows the sidebar and programme panel remain distinct, controls fit, video retains its aspect ratio, and active/focused states can be read independently. A separate cropped comparison was unnecessary: channel labels, programme metadata, buttons, separators and focus outlines were readable in the full-resolution image views. Mobile captures were inspected at their own density, not used for pixel measurements against the desktop concept. CSS viewport and browser console checks do not apply to this native SwiftUI app.

**Required fidelity surfaces**

- **Fonts and typography:** native system sans-serif approximates the concept's clean sans-serif; the image provides no font specification. The spaced VEKTOR TV wordmark, medium navigation, semibold programme title and quieter metadata preserve its hierarchy. tvOS uses 25-point channel names, 22-point metadata and a 40-point programme title. Native mobile text styles adapt to screen size. Real long channel names wrap to two lines and then truncate; complete names remain in accessibility labels. No clipped primary controls were observed.
- **Spacing and layout:** the source's narrow header, channel divider and grouped programme details remain. TV safe-area margins and larger control targets intentionally increase outer spacing. A proper 16:9 video surface replaces the concept's unusually wide picture, with width constrained by available TV height so programme actions and Up next stay visible. iPad keeps the two columns; iPhone places the selected player above the channel controls in one scrolling view. Quiet separators and small corner radii avoid turning the list into unrelated cards.
- **Colors and tokens:** `Theme` uses approximately #090C0F background, #141A1F surfaces, #63DEBF teal, #F0F5F7 primary text and #A8B5C2 secondary text, with 10%-white separators. Teal marks playing state and progress. White focus outlines remain separate from selection. The primary Full screen button has a solid light fill for legibility; this is an intentional native action treatment compared with the mockup's outlined teal button.
- **Image quality and assets:** the landscape represents programme video, so runtime uses a real AVPlayer surface with aspect-fit scaling, not bundled decorative artwork. Provider channel logos load into bounded slots; SF Symbols provide standard controls and a missing-logo fallback. The actual stream is sharp and undistorted in the inspected captures. No generated UI raster is used as interactive app content.
- **Copy and content:** Watch, TV Guide, Your channels, Full screen and Up next retain the concept's plain language. Real channel identities replace invented numbered programme rows. Search, All channels, All groups, refresh, guide and Stop support the existing catalog. Programme times and remaining minutes are computed from guide data. Loading, missing-guide and error copy describe actual app states; no design-process language appears in the interface.

**Comparison history and fixes**

1. **P2, compact content hierarchy:** the initial iPhone implementation placed the channel controls before the selected picture, pushing the viewing area and playback actions down. Evidence: `artifacts/cinema-ios-tests-1-attachments/8E781AF8-3634-4C7C-95A7-3BF360C9DF04.png`, 1206 × 2622, same channel while connecting. The initial compact result was not accepted. Moved the selected player above browser controls, dismissed search on selection and scrolled to the player without remounting it on search changes.
2. **Post-fix comparison:** `artifacts/cinema-iphone.png` at the same viewport and selected channel shows live video immediately below navigation, followed by programme details and all playback actions. Browser controls follow in the same scrolling surface. The initial capture was connecting and the final capture is playing; layout order is the comparable evidence. The final iPhone guide/playback tests passed.
3. **Final wide-screen comparison:** the source and `artifacts/cinema-tvos.png` were viewed together after TV focus and full-screen dismissal fixes. Video, title, progress, actions and Up next are visible while the channel list remains navigable. `artifacts/cinema-ipad.png` confirms the wide adaptation at tablet portrait width. No further visual changes were made after this comparison.

**Interaction evidence**

Checked-in XCTest suites passed on Apple TV, iPhone and iPad. They exercise search, guide and group navigation, live playback, full-screen entry and return, and explicit Stop. The final TV and iPad playback runs also toggle favorites twice and restore the original state. TV scrolling assertions keep focus within screen bounds through fifteen downward and ten upward moves. AVKit's TV dismissal is coordinated with SwiftUI so Back restores browsing without stopping playback.

**Open questions and verification limits**

Physical TV viewing distance, Siri Remote hardware, physical-device audio, VoiceOver, accessibility text sizes, split-window resizing, AirPlay/Picture in Picture and long sessions still need device testing. These are test gaps, not claims of observed failures. Windows retains its existing interface for this Apple release.

**Implementation checklist**

- [x] Preserve the approved visual direction with real channel identity and 16:9 video.
- [x] Keep remote focus distinct from playback selection and verify scrolling.
- [x] Correct compact content hierarchy and verify live playback/full-screen return.
- [x] Inspect Apple TV, iPhone and iPad runtime screenshots.
- [x] Build both Release archives; track distribution separately in [docs/apple-release.md](docs/apple-release.md).

**Follow-up polish**

No P3 item is required for this release. Further TV spacing adjustments should be based on physical viewing-distance testing.

final result: passed
