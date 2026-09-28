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

## Rules
- API keys never ship in the app. The app talks only to the hosted SOE API.
- The plan, progress and session prompt live in `docs/`.
