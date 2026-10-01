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


## Tauri desktop — 0.4.0

Date: 2026-10-01. The approved reference is now implemented in the shared Windows/macOS React interface.

**Evidence and comparison**

- Source: `docs/design/cinema-lounge-reference.png`, 1672 × 941 pixels. The source was displayed together with the actual browser screenshot at 1672 × 941 CSS pixels / 1×, and again with the final native Mac Release screenshot. Both comparisons were made in the same image input, not from memory.
- Mac capture: 2880 × 1884 pixels, approximately 1440 × 942 points at 2× including native title bar, real NRK1 playback and real current/next metadata. Mac captures also show NRK2 playback, guide, fullscreen and post-stop state. These computer-use captures are retained in the chat, rather than committed as image files. The screen-sharing indicator belongs to macOS, not VektorTV.
- Browser preview uses clearly labelled illustrative data and a neutral player placeholder; it cannot play streams. Native captures establish that the large media region is a real player. The runtime video/programme/favorite/history state naturally differs from the concept's fictional programme and landscape frame.
- Responsive checks: 1024 × 680 desktop minimum and 402 × 874 compact preview. The final minimum-size viewing pane fits without inner vertical overflow. The compact layout uses one scrollable column, with picture/actions first. Screenshots were inspected at their respective densities; no cross-density pixel-equality claim is made.

**Five fidelity surfaces**

1. **Typography:** spaced VEKTOR TV wordmark, quiet header labels, 27–38-pixel programme title and lower-contrast metadata preserve the concept hierarchy. SF/Segoe UI system fonts suit desktop platforms. Channel labels increased to 16 pixels after review; long labels truncate within their own rows and retain full accessible names.
2. **Spacing/layout:** compact header, bounded channel sidebar, separators and programme details follow the concept. A true 16:9 picture, constrained by available height, replaces its very wide image. Search/groups/history and extra desktop playback controls are intentional functional additions. Buttons remain below native video so the overlay cannot intercept them.
3. **Color:** charcoal `#0c1013`, panel `#171d22`, teal `#64dfc5`, light primary text and restrained separators. Active channel/navigation/progress use teal; keyboard focus uses a light outline. A solid light Full screen button matches the implemented native Apple treatment.
4. **Media/assets:** native libVLC video preserves aspect ratio, with provider logos in bounded slots and Lucide fallbacks. No screenshot, generated page raster or decorative landscape substitutes for live playback. Mac library loading and title-bar alignment were corrected after testing actual packaged apps.
5. **Copy/content:** Watch, TV Guide, Your channels, Full screen and Up next retain the selected direction. Real channel names replace numbered fictional programme rows. Metadata/progress come from programme timestamps; unavailable, loading and stopped states describe actual player conditions.

**Interaction and corrections**

Browser checks passed navigation, guide details/Watch, favorites, search/group filtering, empty state, Settings and fullscreen/Escape; console had no warnings/errors. Native Mac checks passed visible playback, channel switching, pause/resume, mute/unmute, favorite round-trip, guide/Watch return, fullscreen/Escape, Stop, history persistence and safe shutdown. Two material native issues were fixed: signed VLC-library loading and the title-bar video offset. Final native playback and reference comparison were repeated after the offset fix.

**Boundaries**

No P0/P1/P2 visual differences remain in the inspected Watch layouts. Windows runtime rendering has not been inspected in this Mac session; its shared UI and native code compile and its installer builds in CI. Physical Windows playback, Intel Mac behavior, accessibility text/VoiceOver and multi-monitor changes require device testing. Mac fullscreen captures include system capture/chrome margins; the picture and bottom controls remain visible and interactive. Distribution evidence is in `docs/verification.md` and `docs/apple-release.md`.

final result: passed for the inspected browser and Mac layouts; Windows runtime remains unverified.
