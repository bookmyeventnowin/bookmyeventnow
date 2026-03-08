#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# BookMyEventNow QA Agent — Test Runner
# Called by the QA agent on each cycle.
# Runs flutter unit + widget tests, saves JSON + plain results.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$SCRIPT_DIR/reports"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$REPORTS_DIR"

RESULT_JSON="$REPORTS_DIR/results_${TIMESTAMP}.json"
RESULT_LOG="$REPORTS_DIR/results_${TIMESTAMP}.log"
LATEST_JSON="$REPORTS_DIR/latest_results.json"
LATEST_LOG="$REPORTS_DIR/latest_results.log"

echo "======================================"
echo "  BookMyEventNow QA Agent — Test Run"
echo "  $(date)"
echo "======================================"

cd "$PROJECT_DIR"

# ── Run flutter pub get to ensure deps are fresh ──────────────────────────
echo "[1/3] Running flutter pub get..."
flutter pub get 2>&1 | tee -a "$RESULT_LOG"

# ── Run all unit + widget tests with machine-readable JSON output ──────────
echo "[2/3] Running unit & widget tests..."
EXIT_CODE=0
flutter test test/ \
  --machine \
  --reporter compact \
  2>&1 | tee "$RESULT_JSON" "$RESULT_LOG" || EXIT_CODE=$?

# ── Run unit tests separately with expanded output for readability ─────────
echo "[3/3] Running expanded output for report..."
flutter test test/ \
  --reporter expanded \
  2>&1 | tee -a "$RESULT_LOG" || true

# ── Copy to latest ─────────────────────────────────────────────────────────
cp "$RESULT_JSON" "$LATEST_JSON"
cp "$RESULT_LOG" "$LATEST_LOG"

echo ""
echo "Results saved:"
echo "  JSON : $RESULT_JSON"
echo "  Log  : $RESULT_LOG"

exit $EXIT_CODE
