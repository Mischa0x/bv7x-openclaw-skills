#!/usr/bin/env python3
"""
BV-7X Cron Agent (Python)

Non-interactive daily agent designed for cron scheduling.
Fetches market data, applies a multi-factor strategy, and places
a blind prediction during the 21:00-22:00 UTC window.

Exits silently if the prediction window is closed (cron-safe).

Setup:
    export BV7X_API_KEY="bv7x_your_key_here"
    export BV7X_AGENT_NAME="my-agent"  # optional, for result logging

Cron:
    # Run at 21:15 UTC daily (15 min into blind window)
    15 21 * * * BV7X_API_KEY=your_key /usr/bin/python3 /path/to/cron-agent.py >> /var/log/bv7x-cron.log 2>&1

Requires: Python 3.7+, requests (`pip install requests`)
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

BASE_URL = "https://bv7x.ai/api/bv7x"
LOG_FILE = Path(__file__).parent / ".bv7x-cron-log.json"


def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] {msg}")


def load_log():
    if LOG_FILE.exists():
        try:
            return json.loads(LOG_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {"predictions": []}


def save_log(data):
    LOG_FILE.write_text(json.dumps(data, indent=2))


def fetch_json(url):
    resp = requests.get(url, timeout=15)
    resp.raise_for_status()
    return resp.json()


def check_window():
    """Check if prediction window is open. Returns None if closed."""
    data = fetch_json(f"{BASE_URL}/arena/current-round")
    if data.get("prediction_open"):
        return data
    return None


def get_market_data():
    """Fetch signal endpoint for market context."""
    return fetch_json(f"{BASE_URL}/openclaw/signal")


def strategy(market):
    """
    Multi-factor strategy for daily BTC direction prediction.

    Factors:
    1. Fear & Greed extremes (contrarian)
    2. Oracle signal direction + confidence
    3. Signal strength
    """
    fg = market.get("fearGreed", {}).get("value")
    pars = market.get("parsimonious", {})
    oracle_dir = pars.get("direction")
    oracle_conf = pars.get("confidence", 0)
    strength = market.get("signalStrength", 0)

    score = 0  # positive = UP, negative = DOWN
    reasons = []

    # Factor 1: Fear & Greed extremes (contrarian)
    if fg is not None:
        if fg <= 20:
            score += 2
            reasons.append(f"extreme_fear({fg})")
        elif fg <= 35:
            score += 1
            reasons.append(f"fear({fg})")
        elif fg >= 80:
            score -= 2
            reasons.append(f"extreme_greed({fg})")
        elif fg >= 65:
            score -= 0.5
            reasons.append(f"greed({fg})")

    # Factor 2: Oracle direction weighted by confidence
    if oracle_dir == "UP":
        weight = oracle_conf * 2
        score += weight
        reasons.append(f"oracle_UP(conf={oracle_conf:.2f})")
    elif oracle_dir == "DOWN":
        weight = oracle_conf * 2
        score -= weight
        reasons.append(f"oracle_DOWN(conf={oracle_conf:.2f})")

    # Factor 3: Signal strength
    if abs(strength) > 0.5:
        contribution = strength * 0.5
        score += contribution
        reasons.append(f"strength({strength:.2f})")

    # Decision
    if score > 0.5:
        return "UP", score, reasons
    elif score < -0.5:
        return "DOWN", score, reasons
    else:
        return None, score, reasons


def place_prediction(api_key, direction):
    """Place a blind prediction."""
    resp = requests.post(
        f"{BASE_URL}/arena/bet",
        headers={"Authorization": f"Bearer {api_key}"},
        json={"direction": direction, "round_type": "daily"},
        timeout=15,
    )
    return resp.json()


def main():
    api_key = os.environ.get("BV7X_API_KEY")
    if not api_key:
        log("ERROR: BV7X_API_KEY not set")
        sys.exit(1)

    # Check prediction window
    round_info = check_window()
    if not round_info:
        # Silent exit — cron-safe (window is closed, nothing to do)
        sys.exit(0)

    log("Prediction window is OPEN")

    # Fetch market data
    market = get_market_data()
    btc = market.get("btcPrice", 0)
    fg = market.get("fearGreed", {}).get("value", "?")
    log(f"BTC: ${btc:,.0f}, F&G: {fg}")

    # Run strategy
    direction, score, reasons = strategy(market)

    if not direction:
        log(f"SKIP: no conviction (score={score:.2f}, factors={reasons})")
        sys.exit(0)

    log(f"PREDICTION: {direction} (score={score:.2f}, factors={reasons})")

    # Place prediction
    result = place_prediction(api_key, direction)

    if result.get("success"):
        bet = result["bet"]
        blind = "BLIND " if result.get("blind") else ""
        log(f"{blind}Bet placed: {bet['direction']}, ID: {bet['id']}")

        # Log to file
        history = load_log()
        history["predictions"].append({
            "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "direction": direction,
            "score": round(score, 2),
            "reasons": reasons,
            "blind": result.get("blind", False),
            "bet_id": bet["id"],
            "btc_price": bet.get("btc_price_at_bet"),
        })
        # Keep last 90 days
        history["predictions"] = history["predictions"][-90:]
        save_log(history)
    else:
        error = result.get("error", "Unknown error")
        log(f"BET FAILED: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
