# Windows first

Build a convincing personal Windows IPTV player first. The user will later move development to a Mac for native iOS/tvOS applications. The supplied architecture diagram calls for a shared Rust core and separate platform-native interfaces/playback.

Primary journey: connect the service, load channels, search/filter, select a channel, watch live, save a favorite, inspect now/next and the guide, then reopen with saved metadata and favorites intact.

Source authority: the configured IPTV provider supplies channels, stream locations and programmes. The OS keyring owns the saved connection. SQLite owns cached metadata, favorites and successful viewing history. The interface owns temporary selection and view state. Stream locations never go into frontend DTOs or SQLite.

Observed scale: the initial live Xtream catalog returned 54,745 channels. The complete XMLTV feed exceeded 128 MiB, requiring streaming instead of collecting the response. Channel imports and guide imports have separate success boundaries; missing guides must not prevent watching.

Acceptance: native MPEG-TS playback with decoded video/audio, navigation/search/group filtering, favorites/history after restart, correct programme times, failed-refresh preservation, responsive 1024px and 1440px layouts, Rust/TypeScript checks, production executable launch without Vite and a packaged installer.

Apple deliverable in this phase: a portable core and documented integration boundary. Native Apple apps, bindings and device tests are deliberately deferred to the Mac phase requested by the user.
