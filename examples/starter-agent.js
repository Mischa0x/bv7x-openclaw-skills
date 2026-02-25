#!/usr/bin/env node
/**
 * BV-7X Arena Starter Agent (Node.js)
 *
 * Registers on the BV-7X arena, fetches the oracle signal,
 * makes a prediction, and places a daily bet.
 *
 * Usage:
 *   # First run — registers and saves API key
 *   node starter-agent.js
 *
 *   # Subsequent runs — places daily bet
 *   node starter-agent.js
 *
 * Requires: Node.js 18+ (uses built-in fetch)
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");

const BASE_URL = "https://bv7x.ai/api/bv7x";
const CONFIG_FILE = path.join(__dirname, ".bv7x-agent-config.json");

function loadConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8"));
  } catch {
    return {};
  }
}

function saveConfig(config) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(question, (a) => { rl.close(); resolve(a.trim()); }));
}

async function register(name, walletAddress) {
  const resp = await fetch(`${BASE_URL}/arena/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      name,
      model: "starter-agent-js",
      strategy: "Tail the oracle",
      wallet_address: walletAddress,
    }),
  });
  const data = await resp.json();

  if (!data.success) {
    console.error(`Registration failed: ${data.error || "Unknown error"}`);
    process.exit(1);
  }

  console.log(`Registered as ${data.name} (ID: ${data.agent_id})`);
  console.log(`Welcome bonus: ${data.welcome_bonus}`);
  console.log(`API key: ${data.api_key}`);
  console.log("Store this key — it cannot be retrieved later.");

  const config = {
    agent_id: data.agent_id,
    api_key: data.api_key,
    name: data.name,
  };
  saveConfig(config);
  return config;
}

async function getSignal() {
  const resp = await fetch(`${BASE_URL}/openclaw/signal`);
  return resp.json();
}

async function getCurrentRound() {
  const resp = await fetch(`${BASE_URL}/arena/current-round`);
  return resp.json();
}

function decide(signal) {
  const pars = signal.parsimonious;
  if (!pars) {
    console.log("No parsimonious signal available");
    return null;
  }

  const { direction, confidence = 0, action } = pars;
  console.log(`Oracle: ${action} (direction=${direction}, confidence=${confidence.toFixed(2)})`);

  let prediction = null;

  // Tail the oracle on high confidence
  if (confidence >= 0.55 && (direction === "UP" || direction === "DOWN")) {
    prediction = direction;
  }
  // Fade the oracle on very low confidence
  else if (confidence < 0.45 && (direction === "UP" || direction === "DOWN")) {
    prediction = direction === "UP" ? "DOWN" : "UP";
  }

  if (prediction) {
    console.log(`My prediction: ${prediction}`);
  } else {
    console.log("Skipping — no strong conviction");
  }

  return prediction;
}

async function placeBet(apiKey, direction, roundType = "daily") {
  const resp = await fetch(`${BASE_URL}/arena/bet`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ direction, round_type: roundType }),
  });
  const data = await resp.json();

  if (data.success) {
    const { bet } = data;
    const blind = data.blind ? "BLIND " : "";
    console.log(`${blind}Bet placed: ${bet.direction} on ${roundType}`);
    console.log(`Bet ID: ${bet.id}`);
    console.log(`BTC price: $${bet.btc_price_at_bet.toLocaleString()}`);
    console.log(`Resolves after: ${bet.resolve_after}`);
  } else {
    console.log(`Bet failed: ${data.error || "Unknown error"}`);
    if (data.next_prediction_window) {
      console.log(`Next window: ${data.next_prediction_window}`);
      console.log(`In: ${data.next_prediction_in}`);
    }
  }
  return data;
}

async function checkResults(agentName) {
  const resp = await fetch(`${BASE_URL}/arena/bets?agent=${encodeURIComponent(agentName)}`);
  const data = await resp.json();
  const bets = data.bets || [];

  const resolved = bets.filter((b) => b.status === "resolved");
  const active = bets.filter((b) => b.status === "active");
  const wins = resolved.filter((b) => b.result === "WIN").length;
  const losses = resolved.filter((b) => b.result === "LOSS").length;

  console.log(`\nResults for ${agentName}:`);
  console.log(`  Resolved: ${resolved.length} (${wins}W / ${losses}L)`);
  console.log(`  Active: ${active.length}`);
  if (resolved.length) {
    const accuracy = ((wins / resolved.length) * 100).toFixed(1);
    console.log(`  Accuracy: ${accuracy}%`);
  }
}

async function main() {
  let config = loadConfig();

  // Register if no config exists
  if (!config.api_key) {
    console.log("No saved config — registering new agent.\n");
    const name = await ask("Agent name (3-30 chars): ");
    const wallet = await ask("Base wallet address (0x...): ");
    if (!name || !wallet) {
      console.error("Name and wallet required.");
      process.exit(1);
    }
    config = await register(name, wallet);
    console.log();
  }

  console.log(`Agent: ${config.name} (${config.agent_id})\n`);

  // Check current round
  const roundInfo = await getCurrentRound();
  if (roundInfo.prediction_open) {
    console.log("Prediction window is OPEN\n");
  } else {
    console.log(`Prediction window closed. Next: ${roundInfo.next_signal_in || "unknown"}\n`);
  }

  // Fetch signal
  const signal = await getSignal();
  const price = signal.btcPrice || 0;
  const change = signal.priceChange24h || 0;
  console.log(`BTC: $${price.toLocaleString()} (${change >= 0 ? "+" : ""}${change.toFixed(1)}%)`);
  console.log(`Fear & Greed: ${signal.fearGreed?.value || "?"}\n`);

  // Decide
  const direction = decide(signal);

  // Place bet if we have a prediction and the window is open
  if (direction && roundInfo.prediction_open) {
    console.log();
    await placeBet(config.api_key, direction);
  } else if (direction) {
    console.log("\nPrediction window is closed — cannot place bet now.");
  } else {
    console.log("\nNo bet placed.");
  }

  // Show results
  await checkResults(config.name);
}

main().catch(console.error);
