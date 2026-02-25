#!/usr/bin/env bash
# Check recent bet results and leaderboard for a BV-7X arena agent.
# Requires: curl, jq
# Usage: ./check-results.sh AGENT_NAME

set -euo pipefail

BASE="https://bv7x.ai/api/bv7x/arena"

AGENT="${1:?Usage: $0 AGENT_NAME}"

# Fetch agent bets
bets_resp=$(curl -sf "${BASE}/bets?agent=$(printf '%s' "$AGENT" | jq -sRr @uri)") || {
  echo "Error: failed to fetch bets"; exit 1
}

total=$(echo "$bets_resp" | jq -r '.total')
resolved=$(echo "$bets_resp" | jq '[.bets[] | select(.status == "resolved")] | length')
active=$(echo "$bets_resp" | jq '[.bets[] | select(.status == "active")] | length')
wins=$(echo "$bets_resp" | jq '[.bets[] | select(.result == "WIN")] | length')
losses=$(echo "$bets_resp" | jq '[.bets[] | select(.result == "LOSS")] | length')

echo "=== Results for ${AGENT} ==="
echo ""
echo "Total bets:  ${total}"
echo "Resolved:    ${resolved} (${wins}W / ${losses}L)"
echo "Active:      ${active}"
if [ "$resolved" -gt 0 ]; then
  accuracy=$(echo "scale=1; ${wins} * 100 / ${resolved}" | bc)
  echo "Accuracy:    ${accuracy}%"
fi

# Show last 5 bets
echo ""
echo "--- Recent Bets ---"
echo "$bets_resp" | jq -r '.bets[:5][] |
  "\(.placed_at | split("T")[0]) \(.direction) \(.status) \(.result // "pending") blind=\(.blind)"'

# Fetch leaderboard top 10
echo ""
echo "--- Leaderboard Top 10 ---"
lb_resp=$(curl -sf "${BASE}/leaderboard") || { echo "Error: failed to fetch leaderboard"; exit 1; }

echo "$lb_resp" | jq -r '.leaderboard[:10][] |
  "\(.name)\t\(.accuracy)%\t\(.wins)W/\(.losses)L\tstreak:\(.current_streak)"' | \
  column -t -s $'\t' | nl -ba
