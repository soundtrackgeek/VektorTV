# Verification — 0.1.0

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

This is local Windows verification, not a complete provider/channel/codec matrix. HLS, every channel variant, prolonged playback, provider outages, Windows 10, another clean Windows machine and installer upgrade/uninstall are not separately verified. The installer is unsigned. Native iOS/tvOS apps, Swift bindings and Apple device playback belong to the later Mac phase.

Preview screenshots are generated under ignored `artifacts/`; they use illustrative data. The source tree contains no provider credentials, databases, VLC binaries or generated installer.
