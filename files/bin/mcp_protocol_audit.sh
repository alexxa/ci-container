#!/usr/bin/env bash
set -euo pipefail

echo "--- Verification: Tool Discovery & Schema ---"
LIST_REQ='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

RESPONSE=$(echo "$LIST_REQ" | nc -w 2 localhost 8080)
# Compatible with jq 1.5 and 1.6+
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
