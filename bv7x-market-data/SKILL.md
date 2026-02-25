---
name: bv7x-market-data
description: Access live Bitcoin market context and crowd-vs-oracle comparison data. Use when the user wants BTC price, Fear & Greed, RSI, ETF flows, DXY, MA200 distance, or Polymarket crowd sentiment compared against BV-7X's oracle predictions.
---

# BV-7X Market Data

Read-only access to live Bitcoin market context and a crowd-vs-oracle comparison that tracks Polymarket's weekly BTC direction consensus against BV-7X's oracle signal.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/bv7x/openclaw/signal` | Market data (embedded in signal response) |
| GET | `/api/bv7x/crowd-vs-oracle` | Polymarket crowd vs oracle comparison |

No authentication required.

## Market Data (via Signal Endpoint)

```
GET https://bv7x.ai/api/bv7x/openclaw/signal
```

The signal endpoint includes live market context:

```json
{
  "btcPrice": 95420.50,
  "priceChange24h": 2.3,
  "fearGreed": {
    "value": 62,
    "label": "Greed"
  },
  "etfFlow7d": "+1.2B",
  "etfFlow30d": "+3.8B",
  "etfFlowRaw": {
    "day7": 1200000000,
    "day30": 3800000000
  },
  "signalStrength": 0.87
}
```

| Field | Description |
|-------|-------------|
| `btcPrice` | Current BTC/USD |
| `priceChange24h` | 24h change % |
| `fearGreed.value` | 0-100 Fear & Greed Index |
| `fearGreed.label` | Human-readable sentiment |
| `etfFlow7d` | 7-day net ETF flows (formatted) |
| `etfFlow30d` | 30-day net ETF flows (formatted) |
| `etfFlowRaw` | Raw flow values in USD |
| `signalStrength` | -1.5 to 1.5, composite signal |

## Crowd vs Oracle

```
GET https://bv7x.ai/api/bv7x/crowd-vs-oracle
```

Compares Polymarket's weekly BTC direction consensus against BV-7X's oracle. Updated daily, resolved on a 7-day rolling basis.

### Response

```json
{
  "success": true,
  "data": {
    "summary": {
      "crowd": {
        "total": 15,
        "correct": 9,
        "rate": 0.6,
        "abstained": 2
      },
      "oracle": {
        "total": 15,
        "correct": 10,
        "rate": 0.667,
        "abstained": 0
      }
    },
    "pending": 3,
    "resolved": 15,
    "total_entries": 18,
    "collecting_since": "2026-02-01",
    "recent": [
      {
        "date": "2026-02-18",
        "btc_start": 94500,
        "btc_end": 96200,
        "return_7d": 1.8,
        "crowd": {
          "direction": "UP",
          "probability": 0.62,
          "correct": true
        },
        "oracle": {
          "direction": "UP",
          "action": "BUY",
          "confidence": 0.58,
          "correct": true
        },
        "poly_target_date": "2026-02-25",
        "poly_days_out": 7,
        "poly_atm_strike": 95000,
        "poly_atm_prob": 0.62,
        "poly_slug": "bitcoin-above-on-february-25"
      }
    ],
    "pending_entries": [],
    "next_resolution": {
      "date": "2026-02-25",
      "resolves_on": "2026-03-04"
    }
  },
  "timestamp": "2026-02-25T22:00:00.000Z"
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `summary.crowd.rate` | Polymarket crowd accuracy (0-1) |
| `summary.oracle.rate` | BV-7X oracle accuracy (0-1) |
| `recent[]` | Last 10 resolved matchups |
| `pending_entries[]` | Unresolved matchups |
| `crowd.direction` | Polymarket ATM consensus: UP, DOWN, NEUTRAL |
| `crowd.probability` | ATM YES probability (0-1) |
| `oracle.action` | BV-7X signal: BUY, SELL, HOLD, etc. |
| `poly_slug` | Polymarket event slug for reference |

### Crowd Direction Logic

Crowd direction is derived from Polymarket's at-the-money (ATM) strike:
- YES probability > 0.55 → **UP**
- YES probability < 0.45 → **DOWN**
- Otherwise → **NEUTRAL**

## Common Workflows

### Get market snapshot

```python
import requests

data = requests.get("https://bv7x.ai/api/bv7x/openclaw/signal").json()
print(f"BTC: ${data['btcPrice']:,.0f} ({data['priceChange24h']:+.1f}%)")
print(f"Fear & Greed: {data['fearGreed']['value']} ({data['fearGreed']['label']})")
print(f"ETF 7d: {data['etfFlow7d']}")
```

### Compare crowd vs oracle

```python
cvo = requests.get("https://bv7x.ai/api/bv7x/crowd-vs-oracle").json()
summary = cvo["data"]["summary"]
print(f"Crowd: {summary['crowd']['rate']:.1%}")
print(f"Oracle: {summary['oracle']['rate']:.1%}")
```

## Resources

- [Signal API Reference](../bv7x-signal/references/signal-api.md)
- [Live Dashboard](https://bv7x.ai/bets)
- [Polymarket BTC Markets](https://polymarket.com)

See [references/market-api.md](references/market-api.md) for full endpoint documentation.
