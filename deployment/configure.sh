#!/usr/bin/env bash
# TFGrid WordPress - Configure Script
# Starts containers and configures Caddy reverse proxy

set -e

echo "⚙️ Configuring TFGrid WordPress..."

cd /opt/wordpress

# Load environment
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Get domain (from tfgrid-compose or .env)
DOMAIN="${TFGRID_DOMAIN:-${DOMAIN:-localhost}}"
SSL_EMAIL="${TFGRID_SSL_EMAIL:-${SSL_EMAIL:-}}"

echo "🌐 Configuring for domain: $DOMAIN"

# Configure Caddy
echo "🔧 Configuring Caddy reverse proxy..."
if [ "$DOMAIN" = "localhost" ] || [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # Local/IP - no SSL
    cat > /etc/caddy/Caddyfile <<EOF
# TFGrid WordPress - Local/IP Configuration
http://$DOMAIN {
    reverse_proxy localhost:8080
    
    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
    }
    
    # Logging
    log {
        output file /var/log/caddy/wordpress.log
    }
}
EOF
else
    # Domain - with SSL
    cat > /etc/caddy/Caddyfile <<EOF
# TFGrid WordPress - Production Configuration
$DOMAIN {
    reverse_proxy localhost:8080
    
    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    
    # Logging
    log {
        output file /var/log/caddy/wordpress.log
    }
$([ -n "$SSL_EMAIL" ] && echo "    tls $SSL_EMAIL")
}

# Redirect www to non-www
www.$DOMAIN {
    redir https://$DOMAIN{uri} permanent
}
EOF
fi

# Create Caddy log directory
mkdir -p /var/log/caddy

# Restart Caddy to apply config
echo "🔄 Restarting Caddy..."
systemctl restart caddy

# Start Docker containers
echo "🐳 Starting WordPress containers..."
cd /opt/wordpress
docker compose up -d

# Wait for containers to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if WordPress is responding
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|302\|301"; then
        echo "✅ WordPress is responding"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "⏳ Waiting for WordPress... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "⚠️ WordPress may still be initializing. Check logs with: docker logs wordpress"
fi

# Save configuration info
cat > /opt/wordpress/config/info.json <<EOF
{
    "domain": "$DOMAIN",
    "ssl_email": "$SSL_EMAIL",
    "configured_at": "$(date -Iseconds)",
    "wordpress_url": "https://$DOMAIN",
    "admin_url": "https://$DOMAIN/wp-admin"
}
EOF

echo ""
echo "✅ Configuration complete!"
echo ""
echo "📝 WordPress Details:"
echo "   URL: https://$DOMAIN"
echo "   Admin: https://$DOMAIN/wp-admin"
echo ""
echo "🔧 Management Commands:"
echo "   Logs: tfgrid-compose logs"
echo "   Backup: tfgrid-compose backup"
echo "   Shell: tfgrid-compose shell"
