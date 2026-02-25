#!/usr/bin/env bash
# Fetch BV-7X oracle signal and display key fields.
# Requires: curl, jq
# Usage: ./get-signal.sh

set -euo pipefail

API="https://bv7x.ai/api/bv7x/openclaw/signal"

data=$(curl -sf "$API") || { echo "Error: failed to fetch signal"; exit 1; }

direction=$(echo "$data" | jq -r '.parsimonious.direction')
action=$(echo "$data" | jq -r '.parsimonious.action')
confidence=$(echo "$data" | jq -r '.parsimonious.confidence')
btc=$(echo "$data" | jq -r '.btcPrice')
change=$(echo "$data" | jq -r '.priceChange24h')
fg=$(echo "$data" | jq -r '.fearGreed.value')
fg_label=$(echo "$data" | jq -r '.fearGreed.label')
etf7d=$(echo "$data" | jq -r '.etfFlow7d')
reasoning=$(echo "$data" | jq -r '.parsimonious.reasoning // "N/A"')
accuracy=$(echo "$data" | jq -r '.scorecard.accuracy // "N/A"')
wins=$(echo "$data" | jq -r '.scorecard.wins // 0')
total=$(echo "$data" | jq -r '.scorecard.total // 0')
streak_count=$(echo "$data" | jq -r '.scorecard.streak.count // 0')
streak_type=$(echo "$data" | jq -r '.scorecard.streak.type // "N/A"')
version=$(echo "$data" | jq -r '.modelVersion // "unknown"')

echo "=== BV-7X Oracle Signal (${version}) ==="
echo ""
echo "Direction:   ${direction}"
echo "Action:      ${action}"
echo "Confidence:  ${confidence}"
echo ""
echo "BTC Price:   \$${btc}"
echo "24h Change:  ${change}%"
echo "Fear/Greed:  ${fg} (${fg_label})"
echo "ETF 7d:      ${etf7d}"
echo ""
echo "Reasoning:   ${reasoning}"
echo ""
echo "Scorecard:   ${accuracy}% (${wins}/${total}), streak: ${streak_count} ${streak_type}"
