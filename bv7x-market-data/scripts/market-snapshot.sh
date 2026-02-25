#!/usr/bin/env bash
# Quick Bitcoin market snapshot from BV-7X.
# Requires: curl, jq
# Usage: ./market-snapshot.sh

set -euo pipefail

API="https://bv7x.ai/api/bv7x/openclaw/signal"

data=$(curl -sf "$API") || { echo "Error: failed to fetch market data"; exit 1; }

btc=$(echo "$data" | jq -r '.btcPrice')
change=$(echo "$data" | jq -r '.priceChange24h')
fg=$(echo "$data" | jq -r '.fearGreed.value')
fg_label=$(echo "$data" | jq -r '.fearGreed.label')
etf7d=$(echo "$data" | jq -r '.etfFlow7d')
etf30d=$(echo "$data" | jq -r '.etfFlow30d')
strength=$(echo "$data" | jq -r '.signalStrength')

echo "=== BTC Market Snapshot ==="
echo ""
echo "Price:          \$${btc}"
echo "24h Change:     ${change}%"
echo "Fear/Greed:     ${fg} (${fg_label})"
echo "Signal Strength: ${strength}"
echo "ETF Flow 7d:    ${etf7d}"
echo "ETF Flow 30d:   ${etf30d}"
