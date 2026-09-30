#!/bin/bash
set -euo pipefail
mkdir -p "${CI_PRIMARY_REPOSITORY_PATH:?}/apps/apple/TestFlight"
cat > "$CI_PRIMARY_REPOSITORY_PATH/apps/apple/TestFlight/WhatToTest.en-US.txt" <<'NOTES'
VektorTV native Apple beta: connect your Xtream account or M3U playlist, search channels, filter groups, save favorites, watch HLS live TV, and browse now/next and channel schedules. iOS and tvOS use the shared Rust metadata core with native AVPlayer playback. No IPTV account or content is bundled. Please test audio/video, remote navigation, guide times, account restoration, and favorites/history after restart.
NOTES
