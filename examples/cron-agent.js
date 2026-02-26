#!/usr/bin/env node
/**
 * BV-7X Cron Agent (Node.js)
 *
 * Non-interactive daily agent designed for cron scheduling.
 * Fetches market data, applies a multi-factor strategy, and places
 * a blind prediction during the 21:00-22:00 UTC window.
 *
 * Exits silently if the prediction window is closed (cron-safe).
 *
 * Setup:
 *   export BV7X_API_KEY="bv7x_your_key_here"
 *
 * Cron:
 *   # Run at 21:15 UTC daily (15 min into blind window)
 *   15 21 * * * BV7X_API_KEY=your_key /usr/bin/node /path/to/cron-agent.js >> /var/log/bv7x-cron.log 2>&1
 *
 * Requires: Node.js 18+ (uses built-in fetch)
 */

const fs = require("fs");
const path = require("path");

const BASE_URL = "https://bv7x.ai/api/bv7x";
const LOG_FILE = path.join(__dirname, ".bv7x-cron-log.json");

function log(msg) {
  const ts = new Date().toISOString().replace("T", " ").replace(/\.\d+Z/, " UTC");
  console.log(`[${ts}] ${msg}`);
}

function loadLog() {
  try {
    return JSON.parse(fs.readFileSync(LOG_FILE, "utf8"));
  } catch {
    return { predictions: [] };
  }
}

function saveLog(data) {
  fs.writeFileSync(LOG_FILE, JSON.stringify(data, null, 2));
}

async function fetchJSON(url) {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`HTTP ${resp.status}: ${url}`);
  return resp.json();
}

async function checkWindow() {
  const data = await fetchJSON(`${BASE_URL}/arena/current-round`);
  return data.prediction_open ? data : null;
}

async function getMarketData() {
  return fetchJSON(`${BASE_URL}/openclaw/signal`);
}

/**
 * Multi-factor strategy for daily BTC direction prediction.
 *
 * Factors:
 * 1. Fear & Greed extremes (contrarian)
 * 2. Oracle signal direction + confidence
 * 3. Signal strength
 */
function strategy(market) {
  const fg = market.fearGreed?.value;
  const pars = market.parsimonious || {};
  const oracleDir = pars.direction;
  const oracleConf = pars.confidence || 0;
  const strength = market.signalStrength || 0;

  let score = 0; // positive = UP, negative = DOWN
  const reasons = [];

  // Factor 1: Fear & Greed extremes (contrarian)
  if (fg != null) {
    if (fg <= 20) {
      score += 2;
      reasons.push(`extreme_fear(${fg})`);
    } else if (fg <= 35) {
      score += 1;
      reasons.push(`fear(${fg})`);
    } else if (fg >= 80) {
      score -= 2;
      reasons.push(`extreme_greed(${fg})`);
    } else if (fg >= 65) {
      score -= 0.5;
      reasons.push(`greed(${fg})`);
    }
  }

  // Factor 2: Oracle direction weighted by confidence
  if (oracleDir === "UP") {
    const weight = oracleConf * 2;
    score += weight;
    reasons.push(`oracle_UP(conf=${oracleConf.toFixed(2)})`);
  } else if (oracleDir === "DOWN") {
    const weight = oracleConf * 2;
    score -= weight;
    reasons.push(`oracle_DOWN(conf=${oracleConf.toFixed(2)})`);
  }

  // Factor 3: Signal strength
  if (Math.abs(strength) > 0.5) {
    const contribution = strength * 0.5;
    score += contribution;
    reasons.push(`strength(${strength.toFixed(2)})`);
  }

  // Decision
  if (score > 0.5) return { direction: "UP", score, reasons };
  if (score < -0.5) return { direction: "DOWN", score, reasons };
  return { direction: null, score, reasons };
}

async function placePrediction(apiKey, direction) {
  const resp = await fetch(`${BASE_URL}/arena/bet`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ direction, round_type: "weekly" }),
  });
  return resp.json();
}

async function main() {
  const apiKey = process.env.BV7X_API_KEY;
  if (!apiKey) {
    log("ERROR: BV7X_API_KEY not set");
    process.exit(1);
  }

  // Check prediction window
  const roundInfo = await checkWindow();
  if (!roundInfo) {
    // Silent exit — cron-safe (window is closed, nothing to do)
    process.exit(0);
  }

  log("Prediction window is OPEN");

  // Fetch market data
  const market = await getMarketData();
  const btc = market.btcPrice || 0;
  const fg = market.fearGreed?.value ?? "?";
  log(`BTC: $${btc.toLocaleString()}, F&G: ${fg}`);

  // Run strategy
  const { direction, score, reasons } = strategy(market);

  if (!direction) {
    log(`SKIP: no conviction (score=${score.toFixed(2)}, factors=${JSON.stringify(reasons)})`);
    process.exit(0);
  }

  log(`PREDICTION: ${direction} (score=${score.toFixed(2)}, factors=${JSON.stringify(reasons)})`);

  // Place prediction
  const result = await placePrediction(apiKey, direction);

  if (result.success) {
    const { bet } = result;
    const blind = result.blind ? "BLIND " : "";
    log(`${blind}Bet placed: ${bet.direction}, ID: ${bet.id}`);

    // Log to file
    const history = loadLog();
    history.predictions.push({
      date: new Date().toISOString().split("T")[0],
      direction,
      score: Math.round(score * 100) / 100,
      reasons,
      blind: result.blind || false,
      bet_id: bet.id,
      btc_price: bet.btc_price_at_bet,
    });
    // Keep last 90 days
    history.predictions = history.predictions.slice(-90);
    saveLog(history);
  } else {
    const error = result.error || "Unknown error";
    log(`BET FAILED: ${error}`);
    process.exit(1);
  }
}

main().catch((err) => {
  log(`ERROR: ${err.message}`);
  process.exit(1);
});
