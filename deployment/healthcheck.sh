#!/usr/bin/env bash
# TFGrid WordPress - Health Check Script

set -e

ERRORS=0

echo "🔍 Running WordPress health checks..."

# Check Docker is running
if ! systemctl is-active --quiet docker; then
    echo "❌ Docker is not running"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ Docker is running"
fi

# Check WordPress container
if docker ps --format '{{.Names}}' | grep -q "^wordpress$"; then
    WP_STATUS=$(docker inspect --format='{{.State.Health.Status}}' wordpress 2>/dev/null || echo "running")
    if [ "$WP_STATUS" = "healthy" ] || [ "$WP_STATUS" = "running" ]; then
        echo "✅ WordPress container is $WP_STATUS"
    else
        echo "❌ WordPress container status: $WP_STATUS"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "❌ WordPress container is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check MariaDB container
if docker ps --format '{{.Names}}' | grep -q "^wordpress-db$"; then
    DB_STATUS=$(docker inspect --format='{{.State.Health.Status}}' wordpress-db 2>/dev/null || echo "unknown")
    if [ "$DB_STATUS" = "healthy" ]; then
        echo "✅ MariaDB container is healthy"
    else
        echo "⚠️ MariaDB container status: $DB_STATUS"
    fi
else
    echo "❌ MariaDB container is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check Caddy is running
if systemctl is-active --quiet caddy; then
    echo "✅ Caddy is running"
else
    echo "❌ Caddy is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check WordPress HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
    echo "✅ WordPress HTTP check passed (status: $HTTP_CODE)"
else
    echo "❌ WordPress HTTP check failed (status: $HTTP_CODE)"
    ERRORS=$((ERRORS + 1))
fi

# Check disk space
DISK_USAGE=$(df /opt/wordpress 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -lt 90 ]; then
    echo "✅ Disk usage: ${DISK_USAGE}%"
else
    echo "⚠️ Disk usage is high: ${DISK_USAGE}%"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All health checks passed"
    exit 0
else
    echo "❌ $ERRORS health check(s) failed"
    exit 1
fi
