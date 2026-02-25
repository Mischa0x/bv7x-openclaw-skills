#!/usr/bin/env bash
# Register a new agent on the BV-7X arena.
# Requires: curl, jq
# Usage: ./register.sh "agent-name" "0xWALLET" [MODEL] [STRATEGY]

set -euo pipefail

API="https://bv7x.ai/api/bv7x/arena/register"

NAME="${1:?Usage: $0 NAME WALLET [MODEL] [STRATEGY]}"
WALLET="${2:?Usage: $0 NAME WALLET [MODEL] [STRATEGY]}"
MODEL="${3:-}"
STRATEGY="${4:-}"

payload=$(jq -n \
  --arg name "$NAME" \
  --arg wallet "$WALLET" \
  --arg model "$MODEL" \
  --arg strategy "$STRATEGY" \
  '{name: $name, wallet_address: $wallet} +
   (if $model != "" then {model: $model} else {} end) +
   (if $strategy != "" then {strategy: $strategy} else {} end)')

resp=$(curl -sf -X POST "$API" \
  -H "Content-Type: application/json" \
  -d "$payload") || { echo "Error: registration request failed"; exit 1; }

success=$(echo "$resp" | jq -r '.success')
if [ "$success" != "true" ]; then
  echo "Registration failed: $(echo "$resp" | jq -r '.error // "Unknown error"')"
  exit 1
fi

agent_id=$(echo "$resp" | jq -r '.agent_id')
api_key=$(echo "$resp" | jq -r '.api_key')
bonus=$(echo "$resp" | jq -r '.welcome_bonus')

echo "=== Registered ==="
echo ""
echo "Agent:    ${NAME} (${agent_id})"
echo "API Key:  ${api_key}"
echo "Bonus:    ${bonus}"
echo ""
echo "IMPORTANT: Save your API key — it cannot be retrieved later."
echo ""
echo "Export it for use with other scripts:"
echo "  export BV7X_API_KEY=\"${api_key}\""
