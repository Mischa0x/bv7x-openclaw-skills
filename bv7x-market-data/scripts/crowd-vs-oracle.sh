#!/usr/bin/env bash
# Polymarket crowd vs BV-7X oracle comparison.
# Requires: curl, jq
# Usage: ./crowd-vs-oracle.sh

set -euo pipefail

API="https://bv7x.ai/api/bv7x/crowd-vs-oracle"

data=$(curl -sf "$API") || { echo "Error: failed to fetch crowd-vs-oracle data"; exit 1; }

crowd_total=$(echo "$data" | jq -r '.data.summary.crowd.total')
crowd_correct=$(echo "$data" | jq -r '.data.summary.crowd.correct')
crowd_rate=$(echo "$data" | jq -r '.data.summary.crowd.rate')
crowd_abstained=$(echo "$data" | jq -r '.data.summary.crowd.abstained')

oracle_total=$(echo "$data" | jq -r '.data.summary.oracle.total')
oracle_correct=$(echo "$data" | jq -r '.data.summary.oracle.correct')
oracle_rate=$(echo "$data" | jq -r '.data.summary.oracle.rate')
oracle_abstained=$(echo "$data" | jq -r '.data.summary.oracle.abstained')

pending=$(echo "$data" | jq -r '.data.pending')
resolved=$(echo "$data" | jq -r '.data.resolved')
since=$(echo "$data" | jq -r '.data.collecting_since // "N/A"')

echo "=== Crowd vs Oracle ==="
echo ""
echo "Polymarket Crowd:  ${crowd_correct}/${crowd_total} correct ($(echo "$crowd_rate * 100" | bc)%)"
echo "  Abstained:       ${crowd_abstained}"
echo ""
echo "BV-7X Oracle:      ${oracle_correct}/${oracle_total} correct ($(echo "$oracle_rate * 100" | bc)%)"
echo "  Abstained:       ${oracle_abstained}"
echo ""
echo "Resolved:          ${resolved}"
echo "Pending:           ${pending}"
echo "Tracking since:    ${since}"

# Show latest resolved entry
latest=$(echo "$data" | jq -r '.data.recent[0] // empty')
if [ -n "$latest" ]; then
  date=$(echo "$latest" | jq -r '.date')
  crowd_dir=$(echo "$latest" | jq -r '.crowd.direction')
  oracle_dir=$(echo "$latest" | jq -r '.oracle.direction')
  oracle_action=$(echo "$latest" | jq -r '.oracle.action')
  ret=$(echo "$latest" | jq -r '.return_7d')
  echo ""
  echo "Latest (${date}): Crowd=${crowd_dir}, Oracle=${oracle_action}, Return=${ret}%"
fi
