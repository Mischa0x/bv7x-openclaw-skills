# BV-7X Market Data Heartbeat

Periodic tasks for agents monitoring Bitcoin market context and crowd-vs-oracle performance.

## Schedule

### Every 15-60 minutes — market snapshot

Poll for price, sentiment, and flow changes.

```
Trigger: every 15-60 minutes (your choice of interval)
Endpoint: GET https://bv7x.ai/api/bv7x/openclaw/signal
```

**Steps:**

1. Fetch the signal endpoint
2. Extract `btcPrice`, `priceChange24h`, `fearGreed`, `etfFlow7d`, `signalStrength`
3. Compare with previous snapshot for significant moves
4. Alert or log if price change exceeds your threshold

**Script:**

```bash
./scripts/market-snapshot.sh
```

### Daily — after 22:00 UTC — crowd-vs-oracle check

Compare Polymarket crowd direction against the oracle after the daily signal publishes.

```
Trigger: daily, after 22:00 UTC
Endpoint: GET https://bv7x.ai/api/bv7x/crowd-vs-oracle
```

**Steps:**

1. Fetch crowd-vs-oracle endpoint
2. Extract `summary.crowd.rate` and `summary.oracle.rate`
3. Check `recent[0]` for latest resolved matchup
4. Check `pending_entries` for upcoming resolutions
5. Log agreement/disagreement patterns

**Script:**

```bash
./scripts/crowd-vs-oracle.sh
```

## Example State

```json
{
  "last_market_check": "2026-02-25T15:30:00Z",
  "last_cvo_check": "2026-02-25T22:05:00Z",
  "market": {
    "btcPrice": 95420.50,
    "priceChange24h": 2.3,
    "fearGreed": 62,
    "signalStrength": 0.87
  },
  "crowd_vs_oracle": {
    "crowd_rate": 0.6,
    "oracle_rate": 0.667,
    "last_agreement": true,
    "pending": 3
  }
}
```

## Notes

- Market data is embedded in the signal endpoint (no separate market endpoint needed)
- Crowd-vs-oracle data updates daily, resolves on 7-day rolling basis
- No authentication required for either endpoint
