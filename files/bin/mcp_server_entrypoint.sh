#!/usr/bin/env bash
set -euo pipefail

# 1. Setup pipes with wide permissions for cross-container access
rm -f /tmp/mcp/in /tmp/mcp/out
mkfifo /tmp/mcp/in /tmp/mcp/out
chmod 666 /tmp/mcp/in /tmp/mcp/out

# 2. Setup SSH identity required by MCP
mkdir -p ~/.ssh
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# 3. Keep the input pipe open to prevent premature EOF
sleep infinity > /tmp/mcp/in &

# 4. Launch server and capture stderr for debugging
echo "🚀 Starting MCP Server..."
stdbuf -i0 -o0 -e0 linux-mcp-server < /tmp/mcp/in > /tmp/mcp/out 2>/tmp/mcp/server_stderr.lo
