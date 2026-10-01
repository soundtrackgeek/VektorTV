#!/bin/bash
set -euo pipefail

project_directory="$(cd "$(dirname "$0")/.." && pwd)"
vlc_app="${1:-/Applications/VLC.app}"
if [[ ! -d "$vlc_app" && -d "$HOME/Applications/VLC.app" ]]; then
  vlc_app="$HOME/Applications/VLC.app"
fi
vlc_source="$vlc_app/Contents/MacOS"
runtime_directory="$project_directory/src-tauri/resources/vlc"
if [[ ! -f "$vlc_source/lib/libvlc.dylib" ]]; then
  echo 'Install VLC 3 from https://www.videolan.org/vlc/ or pass its .app path to this script.' >&2
  exit 1
fi
vlc_version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$vlc_app/Contents/Info.plist")"
if [[ "$vlc_version" != 3.* ]]; then
  echo 'The desktop player requires VLC 3.' >&2
  exit 1
fi
mkdir -p "$runtime_directory"
for runtime_folder in lib plugins share; do
  ditto "$vlc_source/$runtime_folder" "$runtime_directory/$runtime_folder"
done
# Include the upstream redistribution notices with the generated runtime.
for notice in COPYING COPYING.LIB AUTHORS; do
  curl --fail --location --silent --show-error --retry 2 \
    "https://raw.githubusercontent.com/videolan/vlc/$vlc_version/$notice" \
    --output "$runtime_directory/$notice"
done
cat > "$runtime_directory/README.txt" <<'EOF'
VLC runtime from the user's installed VLC 3 application.
Upstream source and corresponding releases: https://code.videolan.org/videolan/vlc
VLC and its plugins retain their original licenses. See COPYING, COPYING.LIB,
AUTHORS and https://www.videolan.org/legal.html for redistribution information.
EOF
echo "Prepared macOS VLC runtime in $runtime_directory. Generated files are excluded from Git."
