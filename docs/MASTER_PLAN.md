# Swing Screener: Master Plan

An iOS app that gives a daily shortlist of US stocks for swing trades (holding for days to weeks). It filters out unreliable tickers, attaches a due-diligence card to each name, and flags near-term catalysts.

> This is screening software, not financial advice. The app ranks and informs. It never recommends buying or selling.

---

## 0. Revised approach (2026-09-28, supersedes sections 2, 5, 6 and 7 where they conflict)

Fahad chose to build on the existing **Swing Opportunity Engine** (`Fahad9101/swing-opportunity-engine`, "SOE") instead of starting a fresh backend. SOE already has the universe/reliability filter, setups, 0–100 scoring, catalyst evidence with date confidence, SEC distress checks, biotech runway, and a FastAPI app (`/opportunities`, `/scans`, `/market-regime`, `/health`). On 2026-09-28 its test suite passed locally on Python 3.12 with fixture data.

- **Screening rules:** SOE's `config/soe_v1_0_rules.yaml` is the source of truth. Section 2's defaults are reference only. Changing any SOE threshold needs Fahad's approval.
- **Repos:** SOE stays the backend repo. A new repo holds the SwiftUI app (proposed name: `swing-screener-ios`).
- **Data:** SOE's free stack stays for now (SEC, Nasdaq, Yahoo, Cboe, ClinicalTrials.gov). Swapping Yahoo/Nasdaq for a licensed feed (e.g. Polygon) is a later decision that needs Fahad's approval, because the SOE README marks them prototype-only.

### Revised phases
**Phase 0: Setup.** Create the iOS repo (ask first). Set up the Apple Developer account. Pick hosting for SOE's API and database (proposed: Supabase Postgres for SOE's `DATABASE_URL`, and Render or Fly for the FastAPI app).
✅ Done when: the iOS repo exists with a blank SwiftUI app building in CI, and SOE's hosting choice is logged.

**Phase 1: Host SOE and run it nightly.** Run a GitHub Actions nightly scan in the SOE repo that writes to hosted Postgres. Deploy the FastAPI app. Add a data-freshness field to responses.
✅ Done when: `/opportunities` on the hosted URL returns that night's scan on 5 consecutive trading days.

**Phase 2: Fill API gaps in SOE.** Add a `/ticker/{symbol}` DD-card endpoint (section 4 fields SOE already computes, plus red flags), a `/catalysts` calendar endpoint, watchlist storage, and auth (Supabase JWT). Every change comes with tests, and the frozen scoring rules stay untouched.
✅ Done when: the endpoints are documented and tested, and CI is green.

**Phase 3: iOS app v1.** Same scope as the original Phase 4, calling SOE's API.

**Phase 4: Push and hardening.** Covers APNs alerts and the original Phase 5 checks, ending with 10 clean trading days.

**Phase 5: Backlog.** The original Phase 6 items, plus folding in `Biotech-swing-filter-engine-` FDA/trial logic and a licensed price feed.

---

## 1. Product definition

**Core loop:** Every trading day after the close, a backend job runs the screen. The app shows a ranked shortlist, and tapping a ticker opens its due-diligence (DD) card. A push notification goes out when the shortlist is ready or when a watchlisted name gets a new catalyst.

**Screens in the app (v1):**
1. **Shortlist**: tickers ranked by score, each with setup type, catalyst badge and days to catalyst
2. **Ticker detail / DD card**: chart, the metrics below, catalyst list, recent news, and red flags
3. **Catalyst calendar**: earnings, FDA and other events for the next 30 days, filtered to screened names
4. **Watchlist**: pinned tickers, with alerts on catalyst changes or when a setup triggers
5. **Settings**: screen thresholds (editable presets), notification preferences, data-freshness indicator

**Out of scope for v1:** order execution, brokerage linking, options, crypto, intraday scanning, social features.

---

## 2. Screening criteria (defaults, all user-tunable)

### 2a. Reliability filter (hard exclusions)
| Rule | Default | Why |
|---|---|---|
| Exchange | NYSE, Nasdaq, NYSE American only | Drops OTC and pink sheets |
| Security type | Common stock and ADRs | Drops ETFs, SPACs, warrants, units and preferreds |
| Price | ≥ $10 | Avoids penny-stock dynamics |
| Market cap | ≥ $2B (small-cap preset: ≥ $300M) | Quality and liquidity |
| 30-day average dollar volume | ≥ $20M | Tradable size, tighter spreads |
| Float | ≥ 20M shares | Avoids low-float squeeze names |
| Listing age | ≥ 12 months | Enough price history, no fresh IPOs |
| Reverse split in last 24 months | Excluded | Common distress signal |
| Going-concern / delinquent filer (SEC) | Excluded | Serious risk flag |
| Pending acquisition (definitive deal) | Excluded | Price pinned to the deal |

### 2b. Swing setup (the stock must match at least one)
- **Trend pullback:** close > SMA50 > SMA200, RSI(14) between 40 and 55, price within 3% of SMA20 or SMA50
- **Breakout:** close at a 20-day or 55-day high on volume ≥ 1.5× the 50-day average, ATR% ≤ 6
- **Base / tightening:** 10-day range ≤ 8%, price above SMA50, volume dry-up (10-day average < 0.7× the 50-day average)

### 2c. Scoring (0–100, shown with its breakdown)
- Trend quality 25 (MA alignment, slope, relative strength vs SPY and sector)
- Setup quality 25 (distance to trigger, volatility contraction)
- Fundamentals 20 (revenue growth, EPS trend, margin direction, debt/equity)
- Catalyst 15 (upcoming catalyst inside the holding window, prior earnings reactions)
- Risk 15 (penalties for short-interest extremes, earnings inside 3 days unless opted in, and high beta)

---

## 3. Catalysts

| Catalyst | Source | Window |
|---|---|---|
| Earnings date (with confirmed or estimated flag) | Financial Modeling Prep (FMP) or Finnhub | Next 21 days |
| FDA PDUFA dates and advisory committees | BiopharmCatalyst (paid) or Benzinga Calendar API; fallback: a manually curated list | Next 30 days |
| Investor / analyst days, conferences | FMP or Benzinga | Next 30 days |
| Ex-dividend, splits | FMP / Polygon | Next 14 days |
| Index adds (S&P rebalancing) | News parsing (v2) | As announced |
| Insider buying cluster (Form 4) | SEC EDGAR (free) | Last 30 days |
| Lockup expirations | FMP IPO calendar + 180 days | Next 30 days (flag as risk) |

Each catalyst carries **type, date, whether the date is confirmed, source and last-checked time**. The UI treats catalysts as either risk or opportunity. For example, holding through earnings is flagged, not hidden.

---

## 4. Due-diligence card fields

- **Snapshot:** price, market cap, sector/industry, float, average dollar volume, ATR%, beta
- **Technicals:** trend state, distance to SMA20/50/200, RSI, 52-week high/low distance, relative strength vs SPY and sector
- **Fundamentals:** revenue and EPS growth (YoY, last 4 quarters), gross/operating margin trend, debt/equity, FCF, cash runway (for unprofitable companies)
- **Valuation:** P/E, forward P/E, EV/Sales vs sector median
- **Ownership & flow:** institutional %, insider transactions (90 days), short interest % of float, days to cover
- **Street:** analyst consensus, recent up/downgrades, price-target changes
- **History:** last 4 earnings reactions (gap % and follow-through)
- **Red flags (auto):** dilution (share count +10% YoY), auditor change, late filing, going-concern language, high short interest plus a pending binary event
- **News:** last 7 days of headlines with source links
- **Suggested levels (informational):** ATR-based stop reference and nearest resistance, labeled as reference only

---

## 5. Architecture

```
[Data APIs] → [Nightly pipeline (Python)] → [Postgres / Supabase] → [REST/JSON] → [iOS app (SwiftUI)]
                                                     ↓
                                            [APNs push notifications]
```

- **Pipeline:** Python 3.12, pandas; runs at 5:30 pm ET on trading days, with an intraday catalyst refresh at 9 am ET. Host: GitHub Actions cron (free) at first, moving to Fly.io/Render if needed.
- **Storage & API:** Supabase (Postgres + auto REST + auth + edge functions); the free tier is enough for v1.
- **iOS app:** SwiftUI, iOS 17+, Swift Charts, SwiftData for offline cache. API keys never ship in the app; the app talks only to our backend.
- **Push:** APNs through a Supabase edge function.
- **Repo layout (monorepo):** `pipeline/`, `backend/` (SQL migrations, edge functions), `ios/`, `docs/`.

---

## 6. Data APIs & monthly cost (verify current pricing before buying)

| Need | Primary | Alternative | Est. cost |
|---|---|---|---|
| Daily OHLCV, splits, ticker reference | Polygon.io Stocks Starter | FMP | ~$29/mo |
| Fundamentals, earnings calendar, analyst data, IPO calendar | Financial Modeling Prep Starter/Premium | Finnhub (free tier for earnings) | ~$20–60/mo |
| SEC filings, Form 4 insider trades, going-concern text | SEC EDGAR API | none | Free |
| Short interest | FINRA (bi-monthly) or FMP | Ortex (pricey) | Free–included |
| FDA / biotech catalysts | BiopharmCatalyst | Benzinga Calendar API (quote-based), manual list | ~$20–40/mo or quote |
| News headlines | FMP / Polygon news | Benzinga News API | Included |
| Apple Developer Program | n/a | n/a | $99/yr |
| Hosting | GitHub Actions + Supabase free | Render ~$7/mo | $0–25/mo |

**Estimated v1 total: ~$50–130/month plus $99/year.** Start on free tiers during development and upgrade at Phase 4.

---

## 7. Phases & milestones

Each phase ends with a demo and a go/no-go check before the next one starts.

**Phase 0: Setup**
- Create the GitHub repo (ask Fahad first), plus README and this plan in `docs/`
- Get API keys (Polygon, FMP, Finnhub, SEC user-agent) and store them as GitHub/Supabase secrets
- Set up the Supabase project and the Apple Developer account
- ✅ Done when: the repo exists, secrets are set, and a hello-world pipeline run passes in CI

**Phase 1: Data pipeline & universe**
- Pull the US common-stock universe and apply the 2a reliability filter
- Backfill 2 years of daily bars, then compute indicators (SMA, RSI, ATR, RS)
- Add unit tests for every indicator against known values
- ✅ Done when: a nightly run produces a filtered universe table (~1,000–1,500 names) with indicators, in under 15 minutes

**Phase 2: Screen, score & catalysts**
- Implement the 2b setups and 2c scoring
- Ingest catalysts (earnings, FDA, insider, lockups) into a `catalysts` table
- Write the shortlist table (top 25–50) with score breakdowns
- Backtest sanity check: forward 5/10/20-day returns of past shortlists vs SPY. This validates the tooling, not a promise of results.
- ✅ Done when: the shortlist is generated nightly and the backtest report is in `docs/`

**Phase 3: DD cards & API**
- Assemble DD-card JSON for each shortlisted and watchlisted ticker, including red-flag rules
- Expose Supabase views/endpoints: `/shortlist`, `/ticker/{symbol}`, `/catalysts`, `/watchlist`
- ✅ Done when: every endpoint returns valid JSON matching the documented schema

**Phase 4: iOS app v1**
- SwiftUI screens 1–5, Swift Charts price chart with MAs, offline cache, pull to refresh
- Sign in with Apple (via Supabase auth) for watchlist sync
- Push notifications: shortlist ready, watchlist catalyst added or changed
- ✅ Done when: the app runs on Fahad's iPhone via TestFlight and daily use works end to end

**Phase 5: Hardening**
- Data-freshness checks and a stale-data banner; alerts when the pipeline fails
- Error handling, rate-limit backoff, API-cost monitoring
- Accessibility, dark mode, empty/loading states
- ✅ Done when: 10 consecutive trading days with no manual fixes

**Phase 6: Iterate (v2 backlog)**
- Editable screen presets in the app, sector heatmap, earnings-reaction stats, journal/trade log, intraday alerts, and an App Store release (needs a financial-disclaimer review)

---

## 8. Risks & mitigations
- **Data quality or wrong catalyst dates:** show confirmed/estimated status and source on every date; cross-check earnings dates between two providers
- **API cost creep:** cache aggressively; compute nightly, not on demand
- **Survivorship bias in the backtest:** use point-in-time universes where the provider allows it, and document the limits
- **App Store review:** clear "not financial advice" language, no trade execution
- **Scope creep:** anything not in section 1 goes to the Phase 6 backlog

---

## 9. Decisions log
| Date | Decision |
|---|---|
| 2026-09-28 | Go with a custom iOS app (SwiftUI + Supabase + Python nightly pipeline) |
| 2026-09-28 | Claude asks Fahad before creating repos, writing or pushing code, or opening PRs |
| 2026-09-28 | Build on the existing Swing Opportunity Engine as the backend; the iOS app goes in a separate repo (see section 0) |
