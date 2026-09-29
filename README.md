# Swing Screener (iOS)

A SwiftUI app that shows a daily shortlist of US stocks for swing trades, with a due-diligence card for each name and a flag for near-term catalysts. It is a client of the [Swing Opportunity Engine](https://github.com/Fahad9101/swing-opportunity-engine), which does all the screening and scoring.

> Screening tool, not financial advice.

## Build locally
```sh
brew install xcodegen
xcodegen generate
open SwingScreener.xcodeproj
```
The `.xcodeproj` is generated from `project.yml` and is not committed.

## Try it in a browser (no Mac needed)
Every push to `main` runs the **Simulator build** workflow, which uploads `SwingScreener-simulator.zip`. Download it from the workflow run's Artifacts, unzip the outer download once so you have `SwingScreener-simulator.zip`, and upload that file at https://appetize.io/upload to run the app in a simulated iPhone.

## Run on your iPhone with a free Apple ID
1. In Xcode, open **Settings > Accounts** and add your Apple ID.
2. Select the **SwingScreener** target, open **Signing & Capabilities**, and choose your Personal Team.
3. Plug in the iPhone, pick it as the run destination, and press Run.
4. On the iPhone, turn on **Settings > Privacy & Security > Developer Mode**, and trust the developer under **Settings > General > VPN & Device Management**.

Free-account installs expire after 7 days; press Run again to reinstall.

## Rules
- API keys never ship in the app. The app talks only to the hosted SOE API.
- The plan, progress and session prompt live in `docs/`.
