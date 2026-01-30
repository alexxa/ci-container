#!/usr/bin/env bash
set -euo pipefail

# 1. THE HANDSHAKE (Required by FastMCP)
# We must send 'initialize' first.
INIT_REQ='{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-audit","version":"1.0"}}}'
# Then 'notifications/initialized'
NOTIFY_READY='{"jsonrpc":"2.0","method":"notifications/initialized"}'
# Finally, our tool list request

echo "--- Verification: Tool Discovery & Schema ---"
LIST_REQ='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

echo "--- Phase 4: MCP Protocol Handshake ---"
# We pipe the handshake sequence to the server through the bridge
# The 'sleep' intervals ensure the server processes each step
(echo "$INIT_REQ"; sleep 2; echo "$NOTIFY_READY"; sleep 1; echo "$LIST_REQ"; sleep 5) | nc -w 10 localhost 8080 > /tmp/raw_response.json

# Extract only the last JSON object (the tools/list response)
RESPONSE=$(cat /tmp/raw_response.json | grep "tools/list" || tail -n 1 /tmp/raw_response.json)

#RESPONSE=$(echo "$LIST_REQ" | nc -w 2 localhost 8080)
#RESPONSE=$( (echo "$LIST_REQ"; sleep 10) | nc -w 5 localhost 8080 )
# Compatible with jq 1.5 and 1.6+

echo "--- Available Tools Discovery ---"
# Extract only the names from the tools array for easy reading

if [ -z "$RESPONSE" ]; then
  echo "::error::Received empty response from server. Check sidecar stderr logs."
  exit 1
fi

echo "$RESPONSE" | jq -r '.result.tools[].name' || echo "No tools found in response."

echo "--- Full Response Debug ---"
echo "$RESPONSE" | jq . # Pretty-prints the whole JSON

echo "--- Check for get_system_information tool ---"
echo "$RESPONSE" | jq -e '
  .jsonrpc == "2.0" and 
  .id == 1 and
  (.result.tools | type == "array") and 
  #any(.result.tools[]; .name == "get_system_information")
  (.result.tools | map(select(.name == "get_system_information")) | length > 0)
' > /dev/null || {
  echo "::error::Protocol Audit Failed: Structural invalidity or missing tools."
  exit 1
}
echo "✅ Tool Discovery: Valid."
