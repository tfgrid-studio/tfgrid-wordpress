#!/usr/bin/env bash
# TFGrid WordPress - Shell Script
# Opens an interactive shell in the WordPress container

echo "🐚 Opening WordPress container shell..."
echo "   Type 'exit' to leave"
echo ""

docker exec -it wordpress /bin/bash
