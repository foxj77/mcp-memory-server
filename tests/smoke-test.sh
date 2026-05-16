#!/usr/bin/env bash
# tests/smoke-test.sh — post-deployment smoke test for mcp-memory-server
#
# Exercises all seven MCP memory tools, verifies responses, and prints exactly
# what is being stored and retrieved so you can observe the knowledge graph
# building up across calls.
#
# Usage:
#   ./tests/smoke-test.sh
#   MCP_URL=http://mcp-memory-server.my-namespace.svc.cluster.local:3000/mcp ./tests/smoke-test.sh
#
# Requires: curl, jq
# Exit code: 0 = all tests passed, 1 = one or more failures

MCP_URL="${MCP_URL:-http://localhost:3000/mcp}"
PASS=0
FAIL=0
CALL_ID=1
SESSION_ID=""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

_pass()   { printf "${GREEN}✓${NC} %s\n" "$1";  PASS=$((PASS + 1)); }
_fail()   { printf "${RED}✗${NC} %s\n" "$*";   FAIL=$((FAIL + 1)); }
_info()   { printf "  ${CYAN}→${NC} %s\n" "$1"; }
_header() { printf "\n${YELLOW}━━ %s${NC}\n" "$1"; }

# ── Dependency check ─────────────────────────────────────────────────────────
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        printf "${RED}Error:${NC} '%s' is required but not installed.\n" "$cmd" >&2
        exit 1
    fi
done

# ── Helper: call an MCP tool, return the raw JSON-RPC response ───────────────
mcp_call() {
    local tool="$1" args_json="$2"
    CALL_ID=$((CALL_ID + 1))
    local payload
    payload=$(jq -nc \
        --arg   t   "$tool" \
        --argjson a "$args_json" \
        --argjson id "$CALL_ID" \
        '{jsonrpc:"2.0", id:$id, method:"tools/call", params:{name:$t, arguments:$a}}')
    curl -sf -X POST "$MCP_URL" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "mcp-session-id: $SESSION_ID" \
        -d "$payload" 2>/dev/null \
        | grep '^data:' | head -1 | cut -c7-
}

# ── 1. Initialize session ────────────────────────────────────────────────────
_header "1  Initialize session"
_info "Connecting to $MCP_URL"

INIT_RESP=$(curl -siSf -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}}}' 2>&1) || {
    printf "${RED}Cannot reach %s${NC} — is the server running?\n" "$MCP_URL" >&2
    exit 1
}

SESSION_ID=$(printf '%s' "$INIT_RESP" \
    | grep -i '^mcp-session-id:' \
    | awk '{print $2}' \
    | tr -d '\r\n')

if [[ -n "$SESSION_ID" ]]; then
    _pass "Session established (id: ${SESSION_ID:0:20}…)"
else
    printf "${RED}✗ No mcp-session-id returned${NC} — unexpected server response.\n" >&2
    exit 1
fi

# ── 2. List available tools ──────────────────────────────────────────────────
_header "2  List tools"

CALL_ID=$((CALL_ID + 1))
TOOLS_RESP=$(curl -sf -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "mcp-session-id: $SESSION_ID" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$CALL_ID,\"method\":\"tools/list\",\"params\":{}}" 2>/dev/null \
    | grep '^data:' | head -1 | cut -c7-)

TOOL_COUNT=$(printf '%s' "$TOOLS_RESP" | jq '.result.tools | length' 2>/dev/null || echo 0)
TOOL_NAMES=$(printf '%s' "$TOOLS_RESP" | jq -r '[.result.tools[].name] | join(", ")' 2>/dev/null || echo "")

if [[ "$TOOL_COUNT" -ge 7 ]]; then
    _pass "$TOOL_COUNT tools registered"
    _info "$TOOL_NAMES"
else
    _fail "Expected ≥7 tools, got $TOOL_COUNT"
fi

# ── 3. Pre-run cleanup (idempotent — removes leftovers from a prior failed run) ──
_header "3  Pre-run cleanup"
mcp_call "delete_entities" \
    '{"entityNames":["smoke-test/deployment","smoke-test/incident"]}' >/dev/null 2>&1 || true
_info "Cleared any leftover entities from a previous run"

# ── 4. create_entities ──────────────────────────────────────────────────────
_header "4  create_entities"
_info "Writing two entities to the knowledge graph:"
_info "  smoke-test/deployment  (KubernetesDeployment)"
_info "  smoke-test/incident    (Incident)"

CREATE_RESP=$(mcp_call "create_entities" '{
    "entities": [
        {
            "name": "smoke-test/deployment",
            "entityType": "KubernetesDeployment",
            "observations": [
                "replicas: 3",
                "image: my-app:v1.2.0",
                "namespace: production"
            ]
        },
        {
            "name": "smoke-test/incident",
            "entityType": "Incident",
            "observations": [
                "OOMKilled on 2026-05-16",
                "memory limit was 256Mi at time of incident"
            ]
        }
    ]
}')

if printf '%s' "$CREATE_RESP" | jq -e '.result' &>/dev/null \
&& ! printf '%s' "$CREATE_RESP" | jq -e '.error' &>/dev/null; then
    _pass "Entities created"
    _info "smoke-test/deployment → replicas: 3 | image: my-app:v1.2.0 | namespace: production"
    _info "smoke-test/incident   → OOMKilled on 2026-05-16 | memory limit was 256Mi"
else
    _fail "create_entities failed: $CREATE_RESP"
fi

# ── 5. add_observations ──────────────────────────────────────────────────────
_header "5  add_observations"
_info "Simulating a later agent invocation that appends a new fact without"
_info "overwriting existing observations:"

OBS_RESP=$(mcp_call "add_observations" '{
    "observations": [
        {
            "entityName": "smoke-test/deployment",
            "contents": [
                "memory limit raised to 768Mi after OOMKill incident"
            ]
        }
    ]
}')

if printf '%s' "$OBS_RESP" | jq -e '.result' &>/dev/null \
&& ! printf '%s' "$OBS_RESP" | jq -e '.error' &>/dev/null; then
    _pass "Observation appended"
    _info "smoke-test/deployment → memory limit raised to 768Mi after OOMKill incident"
else
    _fail "add_observations failed: $OBS_RESP"
fi

# ── 6. create_relations ──────────────────────────────────────────────────────
_header "6  create_relations"
_info "Linking the deployment to the incident that triggered its memory limit fix:"

REL_RESP=$(mcp_call "create_relations" '{
    "relations": [
        {
            "from": "smoke-test/deployment",
            "to": "smoke-test/incident",
            "relationType": "fixed_after"
        }
    ]
}')

if printf '%s' "$REL_RESP" | jq -e '.result' &>/dev/null \
&& ! printf '%s' "$REL_RESP" | jq -e '.error' &>/dev/null; then
    _pass "Relation created: smoke-test/deployment → fixed_after → smoke-test/incident"
else
    _fail "create_relations failed: $REL_RESP"
fi

# ── 7. search_nodes ──────────────────────────────────────────────────────────
_header "7  search_nodes"
_info "Querying for 'OOMKilled' — simulates an agent recalling past incidents"
_info "by symptom keyword rather than knowing the entity name upfront:"

SEARCH_RESP=$(mcp_call "search_nodes" '{"query":"OOMKilled"}')

FOUND=$(printf '%s' "$SEARCH_RESP" \
    | jq -r '.result.content[0].text | fromjson | .entities[0].name' 2>/dev/null \
    || echo "")

if [[ "$FOUND" == "smoke-test/incident" ]]; then
    _pass "Returned 'smoke-test/incident' for query 'OOMKilled'"
    _info "Agents can surface relevant past context without knowing entity names"
else
    _fail "Expected 'smoke-test/incident', got '${FOUND:-<empty>}'"
fi

# ── 8. open_nodes ────────────────────────────────────────────────────────────
_header "8  open_nodes"
_info "Fetching smoke-test/deployment by name to inspect its accumulated observations:"

OPEN_RESP=$(mcp_call "open_nodes" '{"names":["smoke-test/deployment"]}')

OBS_COUNT=$(printf '%s' "$OPEN_RESP" \
    | jq '.result.content[0].text | fromjson | .entities[0].observations | length' 2>/dev/null \
    || echo 0)

if [[ "$OBS_COUNT" -ge 4 ]]; then
    _pass "smoke-test/deployment has $OBS_COUNT observations (3 initial + 1 appended)"
    _info "Observations accumulate across agent invocations — this is persistent memory"
    printf '%s' "$OPEN_RESP" \
        | jq -r '.result.content[0].text | fromjson | .entities[0].observations[]' 2>/dev/null \
        | while IFS= read -r obs; do _info "  \"$obs\""; done
else
    _fail "Expected ≥4 observations on smoke-test/deployment, got $OBS_COUNT"
fi

# ── 9. read_graph ────────────────────────────────────────────────────────────
_header "9  read_graph"

GRAPH_RESP=$(mcp_call "read_graph" '{}')

ENTITY_COUNT=$(printf '%s' "$GRAPH_RESP" \
    | jq '.result.content[0].text | fromjson | .entities | length' 2>/dev/null \
    || echo 0)
RELATION_COUNT=$(printf '%s' "$GRAPH_RESP" \
    | jq '.result.content[0].text | fromjson | .relations | length' 2>/dev/null \
    || echo 0)

if [[ "$ENTITY_COUNT" -ge 2 && "$RELATION_COUNT" -ge 1 ]]; then
    _pass "Graph contains $ENTITY_COUNT entities and $RELATION_COUNT relation(s)"
else
    _fail "Expected ≥2 entities and ≥1 relation (got entities=$ENTITY_COUNT relations=$RELATION_COUNT)"
fi

# ── 10. delete_entities (cleanup) ────────────────────────────────────────────
_header "10 delete_entities"
_info "Removing test entities from the graph:"

DEL_RESP=$(mcp_call "delete_entities" \
    '{"entityNames":["smoke-test/deployment","smoke-test/incident"]}')

if printf '%s' "$DEL_RESP" | jq -e '.result' &>/dev/null \
&& ! printf '%s' "$DEL_RESP" | jq -e '.error' &>/dev/null; then
    _pass "smoke-test/deployment and smoke-test/incident deleted"
else
    _fail "delete_entities failed — manual cleanup may be needed: $DEL_RESP"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n%s\n" "────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
    printf "${GREEN}All %d tests passed.${NC} The memory server is working correctly.\n" "$TOTAL"
    exit 0
else
    printf "${RED}%d of %d tests failed.${NC}\n" "$FAIL" "$TOTAL"
    exit 1
fi
