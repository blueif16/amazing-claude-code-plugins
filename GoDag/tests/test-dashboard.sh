#!/usr/bin/env bash
# GoDag Test Suite — validates state.json schema + launches dashboard with mock data
#
# Usage:
#   ./tests/test-dashboard.sh fanout-running     # fan-out DAG, mid-execution
#   ./tests/test-dashboard.sh fanout-complete     # fan-out DAG, all done
#   ./tests/test-dashboard.sh linear-running      # linear chain, mid-execution
#
# Opens dashboard at http://localhost:4567 with the selected fixture.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURE="${1:-fanout-running}"
PORT="${2:-4567}"

# --- Validate fixture exists ---
STATE_FILE="$SCRIPT_DIR/fixtures/${FIXTURE}.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "❌ Fixture not found: $STATE_FILE"
  echo "Available fixtures:"
  ls "$SCRIPT_DIR/fixtures/"*.json 2>/dev/null | xargs -I{} basename {} .json | sed 's/^/  /'
  exit 1
fi

# --- Create temp .godag directory ---
WORK_DIR=$(mktemp -d)
GODAG_DIR="$WORK_DIR/.godag"
mkdir -p "$GODAG_DIR"

echo "📁 Working directory: $GODAG_DIR"

# --- Copy fixture + dashboard ---
cp "$STATE_FILE" "$GODAG_DIR/state.json"
cp "$PLUGIN_DIR/dashboard/index.html" "$GODAG_DIR/dashboard.html"

# Copy matching log.jsonl if it exists
LOG_FILE="$SCRIPT_DIR/fixtures/${FIXTURE}.jsonl"
if [[ -f "$LOG_FILE" ]]; then
  cp "$LOG_FILE" "$GODAG_DIR/log.jsonl"
else
  echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","event":"test_start","data":{"fixture":"'"$FIXTURE"'"}}' > "$GODAG_DIR/log.jsonl"
fi

# --- Kill any existing server on the port ---
lsof -ti:$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true

# --- Start HTTP server ---
cd "$GODAG_DIR"
python3 -m http.server "$PORT" --bind 127.0.0.1 > /dev/null 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > .server.pid

# Give server a moment to start
sleep 0.5

# --- Verify it's running ---
if kill -0 "$SERVER_PID" 2>/dev/null; then
  echo ""
  echo "═══════════════════════════════════════"
  echo "📊 GoDag Dashboard Test"
  echo "═══════════════════════════════════════"
  echo ""
  echo "  Fixture:    $FIXTURE"
  echo "  State:      $GODAG_DIR/state.json"
  echo "  Dashboard:  http://localhost:$PORT/dashboard.html"
  echo "  Server PID: $SERVER_PID"
  echo ""
  echo "  Open in browser:"
  echo "    open http://localhost:$PORT/dashboard.html"
  echo ""
  echo "  To stop:"
  echo "    kill $SERVER_PID"
  echo ""
  echo "═══════════════════════════════════════"

  # Try to open in browser (macOS)
  if command -v open &>/dev/null; then
    open "http://localhost:$PORT/dashboard.html"
  fi
else
  echo "❌ Server failed to start on port $PORT"
  exit 1
fi

# --- Wait for user to kill ---
echo "Press Ctrl+C to stop..."
trap "kill $SERVER_PID 2>/dev/null; rm -rf $WORK_DIR; echo ''; echo '🛑 Stopped.'" EXIT
wait "$SERVER_PID"
