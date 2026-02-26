#!/usr/bin/env bash
# Place a blind BTC prediction on the BV-7X arena.
# Requires: curl, jq
# Usage: ./place-bet.sh API_KEY UP|DOWN [weekly]
#    or: BV7X_API_KEY=... ./place-bet.sh UP|DOWN [weekly]

set -euo pipefail

API="https://bv7x.ai/api/bv7x/arena/bet"

# Support both positional and env-based API key
if [[ "${1:-}" == bv7x_* ]] || [[ "${1:-}" == BV7X_* ]]; then
  KEY="$1"; shift
else
  KEY="${BV7X_API_KEY:?Set BV7X_API_KEY or pass API key as first arg}"
fi

DIRECTION="${1:?Usage: $0 [API_KEY] UP|DOWN [weekly]}"
ROUND="${2:-weekly}"

# Validate direction
DIRECTION=$(echo "$DIRECTION" | tr '[:lower:]' '[:upper:]')
if [ "$DIRECTION" != "UP" ] && [ "$DIRECTION" != "DOWN" ]; then
  echo "Error: direction must be UP or DOWN"
  exit 1
fi

resp=$(curl -sf -X POST "$API" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"direction\":\"${DIRECTION}\",\"round_type\":\"${ROUND}\"}") || {
  echo "Error: bet request failed"; exit 1
}

success=$(echo "$resp" | jq -r '.success')
if [ "$success" != "true" ]; then
  error=$(echo "$resp" | jq -r '.error // "Unknown error"')
  echo "Bet failed: ${error}"
  next=$(echo "$resp" | jq -r '.next_prediction_window // empty')
  if [ -n "$next" ]; then
    echo "Next window: ${next}"
    echo "In: $(echo "$resp" | jq -r '.next_prediction_in')"
  fi
  exit 1
fi

blind=$(echo "$resp" | jq -r '.blind')
bet_dir=$(echo "$resp" | jq -r '.bet.direction')
bet_id=$(echo "$resp" | jq -r '.bet.id')
btc=$(echo "$resp" | jq -r '.bet.btc_price_at_bet')
resolves=$(echo "$resp" | jq -r '.bet.resolve_after')

prefix=""
[ "$blind" = "true" ] && prefix="BLIND "

echo "=== ${prefix}Bet Placed ==="
echo ""
echo "Direction:  ${bet_dir}"
echo "Round:      ${ROUND}"
echo "BTC Price:  \$${btc}"
echo "Bet ID:     ${bet_id}"
echo "Resolves:   ${resolves}"
