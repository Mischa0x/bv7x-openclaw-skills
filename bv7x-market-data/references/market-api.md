# Market Data API Reference

## GET /api/bv7x/openclaw/signal (Market Data Subset)

The signal endpoint returns market context alongside the oracle signal. See [signal-api.md](../../bv7x-signal/references/signal-api.md) for the full response schema.

**Relevant market data fields:**

| Field | Type | Description |
|-------|------|-------------|
| `btcPrice` | number | Current BTC/USD price |
| `priceChange24h` | number | 24-hour change % |
| `fearGreed.value` | number | 0-100, Alternative.me Fear & Greed Index |
| `fearGreed.label` | string | Sentiment label |
| `etfFlow7d` | string | Formatted 7-day net ETF flows |
| `etfFlow30d` | string | Formatted 30-day net ETF flows |
| `etfFlowRaw.day7` | number\|null | Raw 7-day flow USD |
| `etfFlowRaw.day30` | number\|null | Raw 30-day flow USD |
| `signalStrength` | number | -1.5 to 1.5, composite signal |

---

## GET /api/bv7x/crowd-vs-oracle

Polymarket weekly BTC crowd direction vs BV-7X oracle. Tracks head-to-head accuracy.

**Base URL:** `https://bv7x.ai`
**Auth:** None
**Rate limit:** Standard server rate limiting

### Response Schema

```json
{
  "success": true,
  "data": {
    "summary": {
      "crowd": {
        "total": "number — resolved entries where crowd had a direction",
        "correct": "number — crowd was right",
        "rate": "number — accuracy 0.0-1.0",
        "abstained": "number — NEUTRAL entries (no direction)"
      },
      "oracle": {
        "total": "number — resolved entries where oracle had a direction",
        "correct": "number — oracle was right",
        "rate": "number — accuracy 0.0-1.0",
        "abstained": "number — HOLD/NEUTRAL entries"
      }
    },
    "pending": "number — unresolved entries",
    "resolved": "number — resolved entries",
    "total_entries": "number — all entries",
    "collecting_since": "string — YYYY-MM-DD or null",
    "recent": "array — last 10 resolved entries (newest first)",
    "pending_entries": "array — last 10 pending entries (newest first)",
    "next_resolution": {
      "date": "string — YYYY-MM-DD",
      "resolves_on": "string — YYYY-MM-DD"
    }
  },
  "timestamp": "string — ISO 8601"
}
```

### Entry Schema (each item in `recent` and `pending_entries`)

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | Capture date (YYYY-MM-DD) |
| `btc_start` | number | BTC price at capture |
| `btc_end` | number\|null | BTC price at resolution (null if pending) |
| `return_7d` | number\|null | 7-day return % (null if pending) |
| `crowd.direction` | string | `UP`, `DOWN`, or `NEUTRAL` |
| `crowd.probability` | number | Polymarket ATM YES probability, 0-1 |
| `crowd.correct` | boolean\|null | Was crowd right? (null if pending) |
| `oracle.direction` | string | `UP`, `DOWN`, or `NEUTRAL` |
| `oracle.action` | string | `BUY`, `SELL`, `HOLD`, `WEAK_BUY` |
| `oracle.confidence` | number | Oracle confidence, 0-1 |
| `oracle.correct` | boolean\|null | Was oracle right? (null if pending) |
| `poly_target_date` | string\|null | Polymarket resolution target date |
| `poly_days_out` | number\|null | Days between capture and target |
| `poly_atm_strike` | number\|null | ATM strike price |
| `poly_atm_prob` | number\|null | ATM YES probability |
| `poly_slug` | string\|null | Polymarket event slug |

### Crowd Direction Derivation

From Polymarket's ATM strike YES probability:
- `> 0.55` → UP (market expects price above strike)
- `< 0.45` → DOWN (market expects price below strike)
- `0.45 - 0.55` → NEUTRAL (no strong consensus)

ATM strike = closest strike to current BTC price with >= $10K volume.

### Resolution

- Entries resolve on the Polymarket target date at 17:00 UTC (noon ET)
- `correct` is determined by whether BTC actually ended above/below the ATM strike
- For oracle: UP/BUY = correct if price went up, DOWN/SELL = correct if price went down

### Example

```bash
# Get crowd vs oracle comparison
curl -s https://bv7x.ai/api/bv7x/crowd-vs-oracle | jq '.data.summary'
```

```json
{
  "crowd": { "total": 15, "correct": 9, "rate": 0.6, "abstained": 2 },
  "oracle": { "total": 15, "correct": 10, "rate": 0.667, "abstained": 0 }
}
```
