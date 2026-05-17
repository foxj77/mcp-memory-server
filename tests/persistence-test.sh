#!/usr/bin/env bash
# tests/persistence-test.sh — volume persistence test for mcp-memory-server
#
# Verifies three things the smoke test cannot:
#   1. MEMORY_FILE_PATH is set to /data/memory.jsonl in the running container
#   2. Writes go to the host-mounted volume, not inside the container image
#   3. Data survives a full container restart (simulates pod eviction / rollout)
#
# This test exists because of a production bug (v0.2.3) where MEMORY_FILE_PATH
# was unset and server-memory silently wrote to its own npm dist/ directory.
# The MCP API returned success on every call, so the smoke test passed — but all
# data was lost on every pod restart.
#
# Usage:
#   ./tests/persistence-test.sh                         # pull and test :latest
#   ./tests/persistence-test.sh mcp-memory-server:ci    # test a local CI build
#   IMAGE=mcp-memory-server:ci ./tests/persistence-test.sh
#
# Requires: docker, curl, jq

set -euo pipefail

IMAGE="${1:-${IMAGE:-ghcr.io/foxj77/mcp-memory-server:latest}}"
PORT=3001    # separate from the smoke-test container (port 3000) so both can run in parallel
MCP_URL="http://localhost:${PORT}/mcp"
CONTAINER="mcp-persistence-$$"
DATA_DIR=$(mktemp -d)
SESSION_ID=""
CALL_ID=0
PASS=0
FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

_pass()   { printf "${GREEN}✓${NC} %s\n" "$1";  PASS=$((PASS + 1)); }
_fail()   { printf "${RED}✗${NC} %s\n" "$*";   FAIL=$((FAIL + 1)); }
_info()   { printf "  ${CYAN}→${NC} %s\n" "$1"; }
_header() { printf "\n${YELLOW}━━ %s${NC}\n" "$1"; }

cleanup() {
  docker rm -f "$CONTAINER" 2>/dev/null || true
  rm -rf "$DATA_DIR"
}
trap cleanup EXIT INT TERM

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in docker curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    printf "${RED}Error:${NC} '%s' is required but not installed.\n" "$cmd" >&2
    exit 1
  fi
done

wait_ready() {
  local label="${1:-server}"
  _info "Waiting for $label..."
  for i in $(seq 1 20); do
    if curl -sf -o /dev/null -X POST "$MCP_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"healthcheck","version":"1.0"}}}' 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  printf "${RED}Server did not become ready. Container logs:${NC}\n"
  docker logs "$CONTAINER" 2>&1 | tail -20
  exit 1
}

new_session() {
  CALL_ID=0
  local resp
  resp=$(curl -si -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"persistence-test","version":"1.0"}}}' 2>/dev/null)
  SESSION_ID=$(echo "$resp" | grep -i "^mcp-session-id:" | awk '{print $2}' | tr -d '\r\n')
  if [[ -z "$SESSION_ID" ]]; then
    printf "${RED}Error:${NC} No session ID returned from initialize.\n" >&2
    exit 1
  fi
}

mcp_call() {
  local tool="$1" args="$2"
  CALL_ID=$((CALL_ID + 1))
  local payload
  payload=$(jq -nc \
    --arg   tool "$tool" \
    --argjson args "$args" \
    --argjson id  "$CALL_ID" \
    '{jsonrpc:"2.0",id:$id,method:"tools/call",params:{name:$tool,arguments:$args}}')
  curl -sf -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "mcp-session-id: $SESSION_ID" \
    -d "$payload" 2>/dev/null \
    | grep '^data:' | head -1 | cut -c7-
}

printf "Persistence test — image: %s\n" "$IMAGE"

# ── 1. Start container ────────────────────────────────────────────────────────
_header "1  Start container with volume mount"
docker run -d \
  --name "$CONTAINER" \
  -p "${PORT}:3000" \
  -v "${DATA_DIR}:/data" \
  -e NODE_OPTIONS=--max-old-space-size=256 \
  "$IMAGE" >/dev/null
wait_ready "initial start"
_pass "Container started  (port $PORT → volume $DATA_DIR)"

# ── 2. Verify MEMORY_FILE_PATH is set ────────────────────────────────────────
_header "2  Verify MEMORY_FILE_PATH environment variable"
ACTUAL_MFP=$(docker exec "$CONTAINER" sh -c 'echo "$MEMORY_FILE_PATH"' 2>/dev/null | tr -d '\r\n')
if [[ "$ACTUAL_MFP" == "/data/memory.jsonl" ]]; then
  _pass "MEMORY_FILE_PATH=/data/memory.jsonl"
else
  _fail "MEMORY_FILE_PATH is '${ACTUAL_MFP:-<unset>}' — expected '/data/memory.jsonl'"
  _info "Without this env var, server-memory silently writes to its npm dist/"
  _info "directory. The API returns success but all data is lost on restart."
fi

# ── 3. Write an entity ───────────────────────────────────────────────────────
_header "3  Write entity to knowledge graph"
new_session
WRITE_RESP=$(mcp_call "create_entities" '{
  "entities": [{
    "name":       "persistence-test/canary",
    "entityType": "Test",
    "observations": ["written before restart"]
  }]
}')
if echo "$WRITE_RESP" | jq -e '.result' &>/dev/null \
&& ! echo "$WRITE_RESP" | jq -e '.error' &>/dev/null; then
  _pass "Entity 'persistence-test/canary' created"
else
  _fail "create_entities failed: $WRITE_RESP"
fi

# ── 4. Verify the file landed on the host volume ──────────────────────────────
_header "4  Verify memory.jsonl written to mounted volume (not inside image)"
sleep 1   # allow any in-process write to flush
if [[ -s "$DATA_DIR/memory.jsonl" ]]; then
  BYTES=$(wc -c < "$DATA_DIR/memory.jsonl")
  _pass "memory.jsonl found on host volume ($BYTES bytes)"
  _info "$DATA_DIR/memory.jsonl"
else
  _fail "memory.jsonl not found on host volume"
  _info "Searching inside the container for where it was actually written:"
  docker exec "$CONTAINER" find / -name "memory.jsonl" 2>/dev/null \
    | while read -r p; do _info "  $p"; done
fi

# ── 5. Restart the container ─────────────────────────────────────────────────
_header "5  Restart container  (simulates pod eviction or rollout)"
_info "The volume survives the restart — data must be there when the server comes back"
docker restart "$CONTAINER" >/dev/null
wait_ready "restart"
_pass "Container restarted successfully"

# ── 6. Verify data survived ──────────────────────────────────────────────────
_header "6  Verify entity survived container restart"
new_session
READ_RESP=$(mcp_call "open_nodes" '{"names":["persistence-test/canary"]}')
if echo "$READ_RESP" \
    | jq -r '.result.content[0].text | fromjson | .entities[0].observations[]' 2>/dev/null \
    | grep -q "written before restart"; then
  _pass "Entity found with correct observation after restart — persistence confirmed"
else
  _fail "Entity not found after restart — data was NOT persisted to the volume"
  _info "This is the v0.2.3 MEMORY_FILE_PATH bug symptom:"
  _info "  writes appear to succeed but data lives inside the container image,"
  _info "  not on the volume, so it is lost when the container is replaced."
fi

# ── 7. Cleanup ───────────────────────────────────────────────────────────────
_header "7  Cleanup"
mcp_call "delete_entities" '{"entityNames":["persistence-test/canary"]}' >/dev/null || true
_pass "Test entity deleted"

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n%s\n" "────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf "${GREEN}All %d persistence tests passed.${NC}\n" "$TOTAL"
  exit 0
else
  printf "${RED}%d of %d persistence tests failed.${NC}\n" "$FAIL" "$TOTAL"
  exit 1
fi
