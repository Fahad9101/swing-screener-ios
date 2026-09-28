# Progress: Swing Screener

**Current phase:** 0 (Setup)
**Next task:** Create the `swing-screener-ios` repo (waiting on Fahad's go)

## Phase 0 checklist
- [x] Master plan and master prompt written (2026-09-28)
- [x] Audited Fahad's existing repos for overlap (2026-09-28)
- [x] Backend decided: build on SOE (2026-09-28), plan revised in section 0
- [x] SOE test suite runs locally on Python 3.12 with fixtures: all tests pass (2026-09-28)
- [ ] Create `Fahad9101/swing-screener-ios` (private) with a blank SwiftUI app and CI (needs Fahad's go)
- [ ] Choose SOE hosting: Supabase Postgres + Render/Fly (proposed)
- [ ] Get API keys and accounts (Apple Developer, Supabase; paid data only if still needed)
- [ ] Hello-world CI run green

## Findings (2026-09-28)
- `swing-opportunity-engine` (SOE, public, last push 2026-09-03): about 21k lines of Python, 40 test files, CI green on fixtures. It already has:
  - a universe filter (NYSE/Nasdaq, price ≥ $7, market cap ≥ $500M, average dollar volume ≥ $10M, ≥ 120 trading days)
  - technical setups, growth and re-rating rules, and 0–100 scoring with watch/actionable/top tiers
  - catalyst evidence with date confidence and provenance (Nasdaq earnings, ClinicalTrials.gov)
  - biotech cash runway, SEC distress checks, and analyst and ownership data
  - a FastAPI app (`/opportunities`, `/scans`, `/market-regime`, `/health`)
  - free data only (SEC, Nasdaq, Yahoo, Cboe). The README warns that the Yahoo and Nasdaq endpoints are prototype-only, with no SLA.
- `Biotech-swing-filter-engine-` (public, last push 2026-09-22): about 19k lines. It is a biotech-specific engine (FDA, trials, probability-of-success, SEC).
- `Swing-engine-Claude-` is empty.
- This covers most of plan Phases 1–3. What's missing is the iOS app, hosting, push notifications, a watchlist, and a production-grade price feed.

## Blocked
- Repo creation is waiting on Fahad's go.
- The Apple Developer account ($99/yr) is Fahad's to set up.
