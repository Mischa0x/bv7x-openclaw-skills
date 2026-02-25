---
name: bv7x-signal
description: Read BV-7X's daily Bitcoin oracle signal. Use when the user wants to check today's BTC direction prediction, get the oracle's confidence level, see the 4-signal attribution breakdown, or incorporate BV-7X's signal into their own trading strategy.
triggers:
  - get bitcoin signal
  - oracle prediction
  - btc direction today
  - check oracle signal
  - bitcoin forecast
metadata:
  clawdbot:
    emoji: "^"
    homepage: https://bv7x.ai/signal
---

# BV-7X Signal

Read-only access to BV-7X's daily Bitcoin direction signal. The oracle publishes a new signal every day at 22:00 UTC with direction (UP/DOWN/NEUTRAL), action (BUY/SELL/HOLD), confidence, and full reasoning.

## Overview

BV-7X runs a parsimonious signal model (v5.5.1) that combines 4 inputs:
1. **Trend** — MA200 distance + death cross detection
2. **Momentum** — RSI + 7-day rate of change
3. **Flow** — ETF net flows (7d + 30d)
4. **Value** — Drawdown from ATH + recovery signals

The model is calibrated: BUY confidence 57.9%, SELL confidence 61.5% (backtested on 2200+ signals since 2013).

Signal published daily at **22:00 UTC**.

## Endpoint

```
GET https://bv7x.ai/api/bv7x/openclaw/signal
```

No authentication required.

## Response

```json
{
  "signal": "BUY",
  "confidence": 0.58,
  "signalStrength": 0.87,
  "btcPrice": 95420.50,
  "priceChange24h": 2.3,
  "fearGreed": {
    "value": 62,
    "label": "Greed"
  },
  "etfFlow7d": "+1.2B",
  "etfFlow30d": "+3.8B",
  "scorecard": {
    "accuracy": 58.5,
    "wins": 42,
    "losses": 30,
    "total": 72,
    "pending": 1,
    "streak": {
      "count": 3,
      "type": "WIN"
    }
  },
  "parsimonious": {
    "version": "v5.5.1",
    "direction": "UP",
    "action": "BUY",
    "signals": [
      { "name": "trend", "value": 0.6, "weight": 0.3 },
      { "name": "momentum", "value": 0.4, "weight": 0.25 },
      { "name": "flow", "value": 0.8, "weight": 0.25 },
      { "name": "value", "value": 0.3, "weight": 0.2 }
    ],
    "confidence": 0.58,
    "reasoning": "Strong ETF inflows + RSI neutral + above MA200"
  },
  "modelVersion": "v5.5.1",
  "source": "BV-7X",
  "website": "https://bv7x.ai",
  "timestamp": "2026-02-25T22:00:00.000Z",
  "disclaimer": "Not financial advice."
}
```

## Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `signal` | string | `BUY`, `SELL`, or `HOLD` |
| `confidence` | number | 0-1, model confidence |
| `signalStrength` | number | -1.5 to 1.5, raw signal value |
| `btcPrice` | number | Current BTC/USD price |
| `priceChange24h` | number | 24h price change % |
| `fearGreed.value` | number | 0-100 Fear & Greed Index |
| `etfFlow7d` | string | 7-day net ETF flows (formatted) |
| `etfFlow30d` | string | 30-day net ETF flows (formatted) |
| `scorecard` | object | Live prediction track record |
| `parsimonious` | object | Full model breakdown |
| `parsimonious.direction` | string | `UP`, `DOWN`, or `NEUTRAL` |
| `parsimonious.action` | string | `BUY`, `SELL`, `WEAK_BUY`, or `HOLD` |
| `parsimonious.signals` | array | Individual signal components |
| `parsimonious.reasoning` | string | Human-readable rationale |

## Common Workflows

### Get today's signal

```bash
curl https://bv7x.ai/api/bv7x/openclaw/signal
```

### Use the signal in your own strategy

```python
import requests

signal = requests.get("https://bv7x.ai/api/bv7x/openclaw/signal").json()

direction = signal["parsimonious"]["direction"]  # UP, DOWN, NEUTRAL
confidence = signal["parsimonious"]["confidence"]  # 0-1
action = signal["parsimonious"]["action"]  # BUY, SELL, HOLD, WEAK_BUY

# Tail the oracle
if direction == "UP" and confidence > 0.55:
    my_prediction = "UP"
elif direction == "DOWN" and confidence > 0.60:
    my_prediction = "DOWN"
else:
    my_prediction = None  # Skip low-confidence signals
```

### Check the oracle's track record

```python
scorecard = signal["scorecard"]
print(f"Accuracy: {scorecard['accuracy']}% ({scorecard['wins']}/{scorecard['total']})")
print(f"Current streak: {scorecard['streak']['count']} {scorecard['streak']['type']}s")
```

## Signal Schedule

- **22:00 UTC** — New signal published daily
- Before 22:00 UTC — Returns yesterday's signal (or current live calculation)
- The signal endpoint is always available (no auth, no rate limits beyond server defaults)

## Resources

- [Scorecard](https://bv7x.ai/scorecard) — Full prediction history
- [Signal Methodology](https://bv7x.ai/signal) — How the model works
- [Arena](https://bv7x.ai/bets) — Compete against the oracle
