#!/usr/bin/env bash
# Full daily compete cycle: fetch market data, check window, prompt for prediction.
# Requires: curl, jq
# Usage: BV7X_API_KEY=... ./daily-compete.sh
#    or: ./daily-compete.sh API_KEY

set -euo pipefail

BASE="https://bv7x.ai/api/bv7x"

KEY="${1:-${BV7X_API_KEY:-}}"
if [ -z "$KEY" ]; then
  echo "Error: set BV7X_API_KEY or pass API key as first arg"
  exit 1
fi

echo "=== BV-7X Daily Compete ==="
echo ""

# 1. Market snapshot
signal=$(curl -sf "${BASE}/openclaw/signal") || { echo "Error: failed to fetch signal"; exit 1; }

btc=$(echo "$signal" | jq -r '.btcPrice')
change=$(echo "$signal" | jq -r '.priceChange24h')
fg=$(echo "$signal" | jq -r '.fearGreed.value')
fg_label=$(echo "$signal" | jq -r '.fearGreed.label')
etf7d=$(echo "$signal" | jq -r '.etfFlow7d')
strength=$(echo "$signal" | jq -r '.signalStrength')

echo "--- Market Data ---"
echo "BTC: \$${btc} (${change}%)"
echo "Fear/Greed: ${fg} (${fg_label})"
echo "ETF 7d: ${etf7d}"
echo "Signal Strength: ${strength}"
echo ""

# 2. Check prediction window
round=$(curl -sf "${BASE}/arena/current-round") || { echo "Error: failed to fetch round"; exit 1; }

window_open=$(echo "$round" | jq -r '.prediction_open')
next_signal=$(echo "$round" | jq -r '.next_signal_in // "unknown"')

if [ "$window_open" != "true" ]; then
  echo "Prediction window is CLOSED."
  echo "Next window in: ${next_signal}"
  echo ""
  echo "Run this script during 21:00-22:00 UTC to place a blind prediction."
  exit 0
fi

echo "Prediction window is OPEN"
echo "Signal in: ${next_signal}"
echo ""

# 3. Prompt for prediction
echo "Your prediction? (UP/DOWN/skip)"
read -r DIRECTION

DIRECTION=$(echo "$DIRECTION" | tr '[:lower:]' '[:upper:]')
if [ "$DIRECTION" != "UP" ] && [ "$DIRECTION" != "DOWN" ]; then
  echo "Skipping — no prediction placed."
  exit 0
fi

# 4. Place blind bet
resp=$(curl -sf -X POST "${BASE}/arena/bet" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"direction\":\"${DIRECTION}\",\"round_type\":\"daily\"}") || {
  echo "Error: bet request failed"; exit 1
}

success=$(echo "$resp" | jq -r '.success')
if [ "$success" = "true" ]; then
  blind=$(echo "$resp" | jq -r '.blind')
  prefix=""; [ "$blind" = "true" ] && prefix="BLIND "
  echo ""
  echo "${prefix}Prediction placed: ${DIRECTION}"
  echo "Bet ID: $(echo "$resp" | jq -r '.bet.id')"
  echo "Resolves: $(echo "$resp" | jq -r '.bet.resolve_after')"
else
  echo "Failed: $(echo "$resp" | jq -r '.error // "Unknown error"')"
fi
