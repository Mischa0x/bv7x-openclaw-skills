# Signal API Reference

## GET /api/bv7x/openclaw/signal

Returns BV-7X's current Bitcoin signal with full model attribution.

**Base URL:** `https://bv7x.ai`
**Auth:** None required
**Rate limit:** Standard server rate limiting

### Response Fields

#### Core Signal

| Field | Type | Description |
|-------|------|-------------|
| `signal` | string | Simplified signal: `BUY`, `SELL`, or `HOLD` |
| `confidence` | number | Model confidence, 0.0-1.0 |
| `signalStrength` | number | Raw signal value, -1.5 to 1.5 |

#### Price Data

| Field | Type | Description |
|-------|------|-------------|
| `btcPrice` | number | Current BTC/USD price |
| `priceChange24h` | number | 24-hour price change percentage |

#### Sentiment

| Field | Type | Description |
|-------|------|-------------|
| `fearGreed.value` | number | Fear & Greed Index, 0-100 |
| `fearGreed.label` | string | `Extreme Fear`, `Fear`, `Neutral`, `Greed`, `Extreme Greed` |

#### Institutional Flows

| Field | Type | Description |
|-------|------|-------------|
| `etfFlow7d` | string | 7-day net ETF flows, formatted (e.g., `"+1.2B"`, `"-125M"`) |
| `etfFlow30d` | string | 30-day net ETF flows, formatted |
| `etfFlowRaw.day7` | number\|null | Raw 7-day flow in USD |
| `etfFlowRaw.day30` | number\|null | Raw 30-day flow in USD |

#### Scorecard (Live Track Record)

| Field | Type | Description |
|-------|------|-------------|
| `scorecard.accuracy` | number\|null | Win rate percentage |
| `scorecard.wins` | number | Total correct predictions |
| `scorecard.losses` | number | Total incorrect predictions |
| `scorecard.total` | number | Total resolved predictions |
| `scorecard.pending` | number | Predictions awaiting resolution |
| `scorecard.streak.count` | number | Current streak length |
| `scorecard.streak.type` | string\|null | `WIN` or `LOSS` |

#### Parsimonious Model (Full Attribution)

| Field | Type | Description |
|-------|------|-------------|
| `parsimonious.version` | string | Model version (e.g., `v5.5.1`) |
| `parsimonious.direction` | string | `UP`, `DOWN`, or `NEUTRAL` |
| `parsimonious.action` | string | `BUY`, `SELL`, `WEAK_BUY`, or `HOLD` |
| `parsimonious.confidence` | number | Calibrated confidence, 0.0-1.0 |
| `parsimonious.rawConfidence` | number | Uncalibrated confidence |
| `parsimonious.signals` | array | 4 signal components (see below) |
| `parsimonious.reasoning` | string\|null | Human-readable rationale |
| `parsimonious.inputs` | object\|null | Raw model inputs |
| `parsimonious.methodology` | string\|null | Methodology description |

#### Signal Components

Each entry in `parsimonious.signals`:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | `trend`, `momentum`, `flow`, or `value` |
| `value` | number | Component signal value |
| `weight` | number | Component weight in final signal |

#### Metadata

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | Always `"BV-7X"` |
| `website` | string | `"https://bv7x.ai"` |
| `timestamp` | string | ISO 8601 timestamp |
| `modelVersion` | string | Model version |
| `declaredAt` | string\|undefined | When signal was officially declared |
| `disclaimer` | string | Legal disclaimer |

### Model Details

**Version:** v5.5.1
**Calibration:** BUY 57.9%, SELL 61.5% (backtested 2013-2025, 2241 signals)
**Inputs:** trend (MA200), momentum (RSI + ROC), flow (ETF), value (drawdown)
**Actions:** BUY, SELL, WEAK_BUY, HOLD (WEAK_SELL eliminated in v5.5.1)
**Special modes:** Structural bear (death cross + deep below MA200), capitulation (F&G <= 10 + RSI < 30)

### Example Request

```bash
curl -s https://bv7x.ai/api/bv7x/openclaw/signal | jq '.parsimonious'
```

### Example Response (parsimonious subset)

```json
{
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
  "rawConfidence": 0.58,
  "reasoning": "Strong ETF inflows + RSI neutral + above MA200"
}
```
