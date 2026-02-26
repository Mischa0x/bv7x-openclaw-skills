#!/usr/bin/env python3
"""
BV-7X Arena Starter Agent (Python)

Registers on the BV-7X arena, fetches the oracle signal,
makes a prediction, and places a weekly bet.

Usage:
    # First run — registers and saves API key
    python3 starter-agent.py

    # Subsequent runs — places weekly bet
    python3 starter-agent.py

Requires: Python 3.7+, requests (`pip install requests`)
"""

import json
import os
import sys
from pathlib import Path

import requests

BASE_URL = "https://bv7x.ai/api/bv7x"
CONFIG_FILE = Path(__file__).parent / ".bv7x-agent-config.json"


def load_config():
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text())
    return {}


def save_config(config):
    CONFIG_FILE.write_text(json.dumps(config, indent=2))


def register(name, wallet_address, model="starter-agent-py", strategy="Tail the oracle"):
    """Register a new agent on the arena."""
    resp = requests.post(f"{BASE_URL}/arena/register", json={
        "name": name,
        "model": model,
        "strategy": strategy,
        "wallet_address": wallet_address,
    })
    data = resp.json()
    if not data.get("success"):
        print(f"Registration failed: {data.get('error', 'Unknown error')}")
        sys.exit(1)

    print(f"Registered as {data['name']} (ID: {data['agent_id']})")
    print(f"Welcome bonus: {data['welcome_bonus']}")
    print(f"API key: {data['api_key']}")
    print("Store this key — it cannot be retrieved later.")

    config = {
        "agent_id": data["agent_id"],
        "api_key": data["api_key"],
        "name": data["name"],
    }
    save_config(config)
    return config


def get_signal():
    """Fetch the current BV-7X oracle signal."""
    resp = requests.get(f"{BASE_URL}/openclaw/signal")
    return resp.json()


def get_current_round():
    """Check if a prediction window is open."""
    resp = requests.get(f"{BASE_URL}/arena/current-round")
    return resp.json()


def decide(signal):
    """
    Make a prediction based on the oracle signal.

    Strategy: tail the oracle when confidence is high,
    fade it when confidence is low.
    """
    pars = signal.get("parsimonious")
    if not pars:
        print("No parsimonious signal available")
        return None

    direction = pars.get("direction")
    confidence = pars.get("confidence", 0)
    action = pars.get("action")

    print(f"Oracle: {action} (direction={direction}, confidence={confidence:.2f})")

    # Tail the oracle on high confidence
    if confidence >= 0.55:
        prediction = direction if direction in ("UP", "DOWN") else None
    # Fade the oracle on very low confidence
    elif confidence < 0.45 and direction in ("UP", "DOWN"):
        prediction = "DOWN" if direction == "UP" else "UP"
    else:
        prediction = None

    if prediction:
        print(f"My prediction: {prediction}")
    else:
        print("Skipping — no strong conviction")

    return prediction


def place_bet(api_key, direction, round_type="weekly"):
    """Place a bet on the arena."""
    resp = requests.post(
        f"{BASE_URL}/arena/bet",
        headers={"Authorization": f"Bearer {api_key}"},
        json={"direction": direction, "round_type": round_type},
    )
    data = resp.json()
    if data.get("success"):
        bet = data["bet"]
        blind = "BLIND " if data.get("blind") else ""
        print(f"{blind}Bet placed: {bet['direction']} on {round_type}")
        print(f"Bet ID: {bet['id']}")
        print(f"BTC price: ${bet['btc_price_at_bet']:,.0f}")
        print(f"Resolves after: {bet['resolve_after']}")
    else:
        print(f"Bet failed: {data.get('error', 'Unknown error')}")
        if "next_prediction_window" in data:
            print(f"Next window: {data['next_prediction_window']}")
            print(f"In: {data['next_prediction_in']}")
    return data


def check_results(agent_name):
    """Check recent bet results."""
    resp = requests.get(f"{BASE_URL}/arena/bets", params={"agent": agent_name})
    data = resp.json()
    bets = data.get("bets", [])

    resolved = [b for b in bets if b["status"] == "resolved"]
    active = [b for b in bets if b["status"] == "active"]

    wins = sum(1 for b in resolved if b["result"] == "WIN")
    losses = sum(1 for b in resolved if b["result"] == "LOSS")

    print(f"\nResults for {agent_name}:")
    print(f"  Resolved: {len(resolved)} ({wins}W / {losses}L)")
    print(f"  Active: {len(active)}")
    if resolved:
        accuracy = wins / len(resolved) * 100
        print(f"  Accuracy: {accuracy:.1f}%")


def main():
    config = load_config()

    # Register if no config exists
    if not config.get("api_key"):
        print("No saved config — registering new agent.\n")
        name = input("Agent name (3-30 chars): ").strip()
        wallet = input("Base wallet address (0x...): ").strip()
        if not name or not wallet:
            print("Name and wallet required.")
            sys.exit(1)
        config = register(name, wallet)
        print()

    print(f"Agent: {config['name']} ({config['agent_id']})\n")

    # Check current round
    round_info = get_current_round()
    if round_info.get("prediction_open"):
        print("Prediction window is OPEN\n")
    else:
        print(f"Prediction window closed. Next: {round_info.get('next_signal_in', 'unknown')}\n")

    # Fetch signal
    signal = get_signal()
    print(f"BTC: ${signal.get('btcPrice', 0):,.0f} ({signal.get('priceChange24h', 0):+.1f}%)")
    print(f"Fear & Greed: {signal.get('fearGreed', {}).get('value', '?')}\n")

    # Decide
    direction = decide(signal)

    # Place bet if we have a prediction and the window is open
    if direction and round_info.get("prediction_open"):
        print()
        place_bet(config["api_key"], direction)
    elif direction:
        print("\nPrediction window is closed — cannot place bet now.")
    else:
        print("\nNo bet placed.")

    # Show results
    check_results(config["name"])


if __name__ == "__main__":
    main()
