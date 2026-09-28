#!/usr/bin/env bash
# Generates the Xcode project and runs unit tests on the first available iPhone simulator.
set -euo pipefail
xcodegen generate
SIM_ID=$(xcrun simctl list devices available -j \
  | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for k,v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone")))')
xcodebuild test \
  -project SwingScreener.xcodeproj \
  -scheme SwingScreener \
  -destination "id=${SIM_ID}" \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
