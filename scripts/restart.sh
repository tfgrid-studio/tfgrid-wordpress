#!/usr/bin/env bash
# TFGrid WordPress - Restart Script

echo "🔄 Restarting WordPress services..."

cd /opt/wordpress

echo "Restarting containers..."
docker compose restart

echo "Restarting Caddy..."
systemctl restart caddy

echo ""
echo "✅ Services restarted"
echo ""
echo "Check status with: tfgrid-compose healthcheck"
