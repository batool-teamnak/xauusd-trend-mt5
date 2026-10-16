<div align="center">

# Gold Trend State — XAUUSD M1 Trend / Sideways Indicator for MetaTrader 5

**Tells you when gold is trending strongly up, strongly down, or chopping sideways, and alerts you on every change.**

Built to switch a one-direction XAUUSD M1 scalping EA on during strong trends and off during sideways markets.

[![MetaTrader 5](https://img.shields.io/badge/MetaTrader-5-1f6feb?style=flat-square)](https://www.metatrader5.com)
[![MQL5](https://img.shields.io/badge/MQL5-indicator-blue?style=flat-square)](https://www.mql5.com/en/docs)
[![Symbol](https://img.shields.io/badge/XAUUSD-M1-d4a017?style=flat-square)](#)
[![Tested](https://img.shields.io/badge/tested-100%25%20real%20ticks-brightgreen?style=flat-square)](#test-results)

</div>

---

## What it does

A separate-window histogram under your XAUUSD M1 chart with three states:

| Bar | State | Meaning |
|---|---|---|
| 🟩 green, full height | **STRONG UP** | buyers dominant, confirmed on M5 and M15 |
| 🟥 red, full height | **STRONG DOWN** | sellers dominant, confirmed on M5 and M15 |
| ⬜ grey, short | **SIDEWAYS** | no dominant side, chop |
| 🟧 orange, short | **SPREAD HIGH** | spread above your limit on that bar, no signals |

A label shows the live state and current spread. A **popup, sound and mobile push alert** fires every time the state changes.

## Why a gold M1 scalper needs it

A trend-following scalper that keeps buying (or selling) once it starts does well when gold
runs in one direction and bleeds stop losses when it goes sideways. M1 alone is too noisy to
tell the two apart, so the decision is made on M5 and M15 and only shown on M1.

## How the state is decided

All checks use **closed** M5/M15 bars only, so the indicator **does not repaint**.

A bar is **STRONG UP** when all of these agree (mirror for STRONG DOWN):

1. **M5 trend** — EMA 21 above EMA 50 and price above EMA 21
2. **M15 trend** — same EMA test, same direction
3. **M5 strength** — ADX(14) ≥ 25 and +DI above −DI
4. **M5 market structure** — higher highs and higher lows from swing pivots *(optional)*
5. **Confirmation** — the new state must hold for 3 M1 bars before switching, which cuts flicker

Anything else is **SIDEWAYS**.

## Spread filter

Raw/ECN gold scalping only works with tight spread. With the filter on, no alert fires while
spread is above `InpMaxSpreadPips` (default **0.9 pip**). When spread drops back, you get the
current state straight away, so a change is never missed.

`InpPointsPerPip = 10` means 1 pip = 10 points = $0.10 on 2-digit gold, so 0.9 pip = $0.09.
If your broker quotes 3 digits, or you count pips differently, adjust this one input.

## Inputs

| Group | Input | Default | |
|---|---|---|---|
| Timeframes | `InpTfFast` / `InpTfSlow` | M5 / M15 | confirmation timeframes |
| Trend | `InpEmaFast` / `InpEmaSlow` | 21 / 50 | EMA trend filter |
| | `InpAdxPeriod` / `InpAdxMin` | 14 / 25 | higher ADX = fewer, stronger trend signals |
| | `InpUseStructure` | true | require HH/HL or LH/LL on M5 |
| | `InpSwingStrength` | 3 | bars each side of a swing pivot |
| | `InpConfirmBars` | 3 | M1 bars a new state must hold |
| Spread | `InpUseSpread` / `InpMaxSpreadPips` / `InpPointsPerPip` | true / 0.9 / 10 | |
| Alerts | `InpAlertPopup` / `InpAlertSound` / `InpAlertPush` | all on | push needs MetaQuotes ID set in MT5 |
| Display | `InpMaxBars` / `InpShowLabel` | 5000 / true | |

**Tuning:** more sensitive → lower `InpAdxMin` (20) or set `InpUseStructure=false`.
Fewer, stronger signals → raise `InpAdxMin` (30) or `InpConfirmBars` (5).

## Install

1. MT5 → **File → Open Data Folder → MQL5 → Indicators**
2. Copy `Gold_Trend_State.ex5` (or `.mq5`) there
3. Restart MT5, or right-click **Indicators → Refresh** in the Navigator
4. Drag **Gold_Trend_State** onto an **XAUUSD M1** chart
5. For phone alerts: **Tools → Options → Notifications**, enter your MetaQuotes ID from the MT5 mobile app

## Test results

XAUUSD M1, **1 Jul – 30 Sep 2026**, MetaQuotes-Demo, **100% real ticks**, default inputs,
measured by the harness in [`tests/GTS_Probe.mq5`](tests/GTS_Probe.mq5) running the
indicator inside the MT5 strategy tester.

| | |
|---|---|
| M1 bars | 85 525 |
| Time in STRONG UP / STRONG DOWN / SIDEWAYS | 10.0% / 9.3% / 80.7% |
| State changes | 15.1 per day, average state lasts ~91 min |
| Avg 30-bar price range in trend states vs sideways | $6.87 vs $5.94 |
| Price moved in the state's direction over the next 30 bars | 49.3% |

**What this means, plainly:**

- Most of the time gold M1 is classified sideways, and trend states last long enough (~1.5 h)
  to act on manually, not just flicker.
- Trend states have noticeably larger moves than sideways ones — the indicator does separate
  "moving" markets from "chop".
- It is **not** a direction predictor. Once a trend state is on, the next move is close to a
  coin flip in direction. Use it to decide **when to run or stop** your EA, not as an entry signal.

### Proxy scalper, with vs without the filter

The client's EA has no source, so it can't be backtested here. As a stand-in, the probe runs a
naive M1 EMA scalper (0.1 lot, $0.25 TP / $0.40 SL) twice: once always on, once only while
the indicator shows the matching strong state. Same period, same real ticks.

| | always on | only in strong state |
|---|---|---|
| Trades | 4 069 | 3 417 |
| Win rate | 33.62% | 24.70% |
| Profit factor | 0.32 | 0.23 |
| Max equity drawdown | 96.20% | 95.90% |

Both blow the account. A $0.25 target against this demo's ~$0.20 spread has no edge, and the
filter does not change that. **The indicator is not a fix for an entry that loses on its own.**
Its value is as a manual run / stop switch for an EA that already makes money in trends and
gives it back in chop. Check it against your own EA's trade history before relying on it.

Spread on this demo server was a median 2.0 pip, so a 0.9 pip filter would block most bars
there. On a raw/ECN account, spread is much tighter — set the limit to your broker.

To reproduce: copy `Gold_Trend_State.ex5` into `MQL5/Indicators`, compile `tests/GTS_Probe.mq5`
in MetaEditor, then run it in the Strategy Tester on XAUUSD M1, 2026.07.01 – 2026.09.30,
"Every tick based on real ticks", loading inputs from `tests/sets/mode2.set`.

`InpMode` in the probe: `2` state statistics only, `0` proxy scalper always on, `1` proxy scalper only in the matching strong state.

## Files

| | |
|---|---|
| `Gold_Trend_State.mq5` | indicator source |
| `Gold_Trend_State.ex5` | compiled, ready to drop into MT5 |
| `tests/GTS_Probe.mq5` | strategy tester harness: state stats + filtered vs unfiltered proxy scalper |
| `tests/sets/` | tester input sets |
| `tests/results/` | raw tester output |

## Disclaimer

Indicator only. It does not place, modify or close trades, and does not control any EA.
No profit or performance guarantee. Test on demo first.

---

**Keywords:** MT5 indicator, MetaTrader 5, MQL5, XAUUSD, gold, M1 scalping, trend filter,
sideways market detector, range filter, chop filter, ADX, EMA, market structure,
higher high higher low, multi-timeframe, spread filter, trend alert, push notification, EA filter.

Built by [Batool](https://github.com/batool-teamnak) — custom MT4/MT5 EAs and indicators.
