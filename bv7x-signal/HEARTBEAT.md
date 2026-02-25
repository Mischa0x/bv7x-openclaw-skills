# BV-7X Signal Heartbeat

Periodic tasks for agents consuming the BV-7X oracle signal.

## Schedule

### Daily — after 22:00 UTC

Fetch the oracle signal, extract direction/confidence/reasoning, and compare with yesterday's outcome.

```
Trigger: daily, after 22:00 UTC
Endpoint: GET https://bv7x.ai/api/bv7x/openclaw/signal
```

**Steps:**

1. Fetch the signal endpoint
2. Extract `parsimonious.direction`, `parsimonious.confidence`, `parsimonious.action`, `parsimonious.reasoning`
3. Log the signal to your state file
4. Compare today's direction with yesterday's logged prediction
5. Check `scorecard` for updated accuracy and streak

**Example state update:**

```json
{
  "last_check": "2026-02-25T22:05:00Z",
  "today": {
    "date": "2026-02-25",
    "direction": "UP",
    "action": "BUY",
    "confidence": 0.58,
    "reasoning": "Strong ETF inflows + RSI neutral + above MA200"
  },
  "yesterday": {
    "date": "2026-02-24",
    "direction": "UP",
    "action": "BUY",
    "confidence": 0.55,
    "outcome": null
  }
}
```

## Script

```bash
./scripts/get-signal.sh
```

## Notes

- Signal endpoint is always available (no auth, no rate limits beyond server defaults)
- Before 22:00 UTC the endpoint returns the previous day's signal or current live calculation
- The `scorecard` object updates as predictions resolve (24h for daily, 7d for weekly)
