#!/usr/bin/env bash
# TFGrid WordPress - Logs Script

SERVICE="${1:-all}"
FOLLOW=""

# Check for --follow flag
for arg in "$@"; do
    if [ "$arg" = "--follow" ] || [ "$arg" = "-f" ]; then
        FOLLOW="-f"
    fi
done

case "$SERVICE" in
    wordpress|wp)
        echo "📋 WordPress logs:"
        docker logs $FOLLOW wordpress
        ;;
    db|database|mariadb|mysql)
        echo "📋 MariaDB logs:"
        docker logs $FOLLOW wordpress-db
        ;;
    caddy|proxy)
        echo "📋 Caddy logs:"
        if [ -n "$FOLLOW" ]; then
            tail -f /var/log/caddy/wordpress.log
        else
            tail -100 /var/log/caddy/wordpress.log
        fi
        ;;
    all|"")
        echo "📋 All service logs (last 50 lines each):"
        echo ""
        echo "=== WordPress ==="
        docker logs --tail 50 wordpress 2>&1
        echo ""
        echo "=== MariaDB ==="
        docker logs --tail 50 wordpress-db 2>&1
        echo ""
        echo "=== Caddy ==="
        tail -50 /var/log/caddy/wordpress.log 2>/dev/null || echo "No Caddy logs yet"
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Usage: logs.sh [wordpress|db|caddy|all] [--follow]"
        exit 1
        ;;
esac
