# Third-party software

VektorTV's Windows and macOS players load the VLC 3 libVLC runtime. Development can use a locally installed 64-bit VLC, and the packaging preparation script copies its libraries/plugins and original `COPYING.txt`, `AUTHORS.txt` and `README.txt` into the bundled `vlc` directory.

VLC components are licensed independently of VektorTV. libVLC is made available under LGPL terms; included VLC plugins and other components may use GPL or other licenses. Preserve the original notices supplied with the specific VLC installation. The VLC source is available from [VideoLAN's VLC source repository](https://code.videolan.org/videolan/vlc); matching release source archives are available from [VideoLAN downloads](https://download.videolan.org/pub/videolan/vlc/).

The Mac script copies `lib`, `plugins` and `share` from VLC.app and includes the matching release’s `COPYING`, `COPYING.LIB` and `AUTHORS` notices. Match the runtime architecture to the app.

The application dynamically links the copied runtime and does not modify VLC. A distribution intended for public release must review the licenses of its selected plugins and fulfill any corresponding-source/redistribution obligations. Windows installers are unsigned; local Mac bundles use ad-hoc signing and are not notarized.

React, Tauri, Lucide, SQLite and the other dependencies retain their own licenses in their packages. `package-lock.json` and `Cargo.lock` record the exact dependency versions.
