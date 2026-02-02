#!/usr/bin/env bash
set -euo pipefail

echo "--- Phase 1: Establishing Bridge ---"
# Wait for sidecar pipes to be ready
until [ -p /tmp/mcp/in ]; do sleep 1; done

# Start bridge in background.
socat TCP-LISTEN:8080,reuseaddr,fork SYSTEM:'cat > /tmp/mcp/in | tee /dev/stderr | cat /tmp/mcp/out' &
BRIDGE_PID=$!

echo "--- Phase 2: Connectivity Check ---"
timeout 30s bash -c 'until nc -z localhost 8080; do sleep 1; done' || {
    echo "::error::Bridge failed to listen on 8080"
    exit 1
}

echo "--- Phase 3: MCP Protocol Handshake ---"
# The Handshake sequence required by MCP servers
INIT_REQ='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-audit","version":"1.0"}}}'
NOTIFY_READY='{"jsonrpc":"2.0","method":"notifications/initialized"}'
LIST_REQ='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

# We pipe the handshake sequence to the server through the bridge
# The 'sleep' intervals ensure the server processes each step
(echo "$INIT_REQ"; sleep 2; echo "$NOTIFY_READY"; sleep 1; echo "$LIST_REQ"; sleep 5) | \
    nc -w 10 localhost 8080 > /tmp/raw_response.json

# Extract only the last JSON object (the tools/list response)
RESPONSE=$(cat /tmp/raw_response.json | grep "tools/list" || tail -n 1 /tmp/raw_response.json)

if [ -z "$RESPONSE" ] || [ "$RESPONSE" == "null" ]; then
  echo "::error::Received empty response from server."
  exit 1
fi

echo "--- Phase 4: Available Tools Discovery ---"
echo "$RESPONSE" | jq -r '.result.tools[].name' || echo "No tools found in response."

echo "--- Full Response Debug ---"
echo "$RESPONSE" | jq . # Pretty-prints the whole JSON

echo "--- Check for get_system_information tool ---"
echo "$RESPONSE" | jq -e '
  .jsonrpc == "2.0" and 
  .id == 1 and
  (.result.tools | type == "array") and 
  (.result.tools | map(select(.name == "get_system_information")) | length > 0)
' > /dev/null || {
  echo "::error::Protocol Audit Failed: Structural invalidity or missing tools."
  exit 1
}

echo "✅ Tool Discovery: Valid."
