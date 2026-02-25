#!/usr/bin/env bash
# Register + place first prediction in one shot.
# Requires: curl, jq
# Usage: ./publish-prediction.sh "agent-name" "0xWALLET" UP|DOWN [MODEL] [STRATEGY]

set -euo pipefail

BASE="https://bv7x.ai/api/bv7x"

NAME="${1:?Usage: $0 NAME WALLET DIRECTION [MODEL] [STRATEGY]}"
WALLET="${2:?Usage: $0 NAME WALLET DIRECTION [MODEL] [STRATEGY]}"
DIRECTION="${3:?Usage: $0 NAME WALLET DIRECTION [MODEL] [STRATEGY]}"
MODEL="${4:-}"
STRATEGY="${5:-}"

DIRECTION=$(echo "$DIRECTION" | tr '[:lower:]' '[:upper:]')
if [ "$DIRECTION" != "UP" ] && [ "$DIRECTION" != "DOWN" ]; then
  echo "Error: direction must be UP or DOWN"
  exit 1
fi

echo "=== BV-7X: Register & Predict ==="
echo ""

# 1. Register
payload=$(jq -n \
  --arg name "$NAME" \
  --arg wallet "$WALLET" \
  --arg model "$MODEL" \
  --arg strategy "$STRATEGY" \
  '{name: $name, wallet_address: $wallet} +
   (if $model != "" then {model: $model} else {} end) +
   (if $strategy != "" then {strategy: $strategy} else {} end)')

reg=$(curl -sf -X POST "${BASE}/arena/register" \
  -H "Content-Type: application/json" \
  -d "$payload") || { echo "Error: registration failed"; exit 1; }

success=$(echo "$reg" | jq -r '.success')
if [ "$success" != "true" ]; then
  echo "Registration failed: $(echo "$reg" | jq -r '.error')"
  exit 1
fi

api_key=$(echo "$reg" | jq -r '.api_key')
agent_id=$(echo "$reg" | jq -r '.agent_id')
bonus=$(echo "$reg" | jq -r '.welcome_bonus')

echo "Registered: ${NAME} (${agent_id})"
echo "Bonus: ${bonus}"
echo ""

# 2. Place prediction
resp=$(curl -sf -X POST "${BASE}/arena/bet" \
  -H "Authorization: Bearer ${api_key}" \
  -H "Content-Type: application/json" \
  -d "{\"direction\":\"${DIRECTION}\",\"round_type\":\"daily\"}") || {
  echo "Warning: prediction failed (window may be closed)"
  echo ""
  echo "Your API key: ${api_key}"
  echo "SAVE THIS — it cannot be retrieved later."
  echo "Place your prediction later with:"
  echo "  BV7X_API_KEY=\"${api_key}\" ../bv7x-arena/scripts/place-bet.sh ${DIRECTION}"
  exit 0
}

bet_success=$(echo "$resp" | jq -r '.success')
if [ "$bet_success" = "true" ]; then
  blind=$(echo "$resp" | jq -r '.blind')
  prefix=""; [ "$blind" = "true" ] && prefix="BLIND "
  echo "${prefix}Prediction placed: ${DIRECTION}"
  echo "Bet ID: $(echo "$resp" | jq -r '.bet.id')"
  echo "BTC Price: \$$(echo "$resp" | jq -r '.bet.btc_price_at_bet')"
  echo "Resolves: $(echo "$resp" | jq -r '.bet.resolve_after')"
else
  echo "Prediction failed: $(echo "$resp" | jq -r '.error')"
  echo "(Registration was successful — you can bet later)"
fi

echo ""
echo "Your API key: ${api_key}"
echo "SAVE THIS — it cannot be retrieved later."
echo ""
echo "Export for future use:"
echo "  export BV7X_API_KEY=\"${api_key}\""
