#!/usr/bin/env bash
# TFGrid WordPress - Setup Script
# Installs Docker, Docker Compose, and Caddy

set -e

# Suppress debconf warnings in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Setting up TFGrid WordPress..."

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install prerequisites
echo "📦 Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    pwgen

# Install fuse-overlayfs for Docker storage (may be needed as fallback)
echo "📦 Installing fuse-overlayfs..."
apt-get install -y fuse-overlayfs

# Function to configure Docker storage driver with fallback
configure_docker_storage() {
    local driver="$1"
    echo "🔧 Configuring Docker with storage driver: $driver"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "storage-driver": "$driver"
}
EOF
    # Stop docker, clear old storage, restart
    systemctl stop docker 2>/dev/null || true
    rm -rf /var/lib/docker/* 2>/dev/null || true
    systemctl start docker
    sleep 2
}

# Function to test Docker storage driver
test_docker_storage() {
    echo "🧪 Testing Docker storage driver..."
    if docker pull hello-world >/dev/null 2>&1 && docker run --rm hello-world >/dev/null 2>&1; then
        echo "✅ Docker storage driver working"
        docker rmi hello-world >/dev/null 2>&1 || true
        return 0
    else
        echo "⚠️ Docker storage driver test failed"
        return 1
    fi
}

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    
    # Try storage drivers in order of preference: fuse-overlayfs, vfs
    # TFGrid VMs may have filesystem limitations that prevent overlay2/fuse-overlayfs
    
    # First try fuse-overlayfs
    configure_docker_storage "fuse-overlayfs"
    if ! test_docker_storage; then
        echo "⚠️ fuse-overlayfs failed, falling back to vfs driver"
        configure_docker_storage "vfs"
        if ! test_docker_storage; then
            echo "❌ All storage drivers failed"
            exit 1
        fi
    fi
else
    echo "✅ Docker already installed"
    
    # Check if current storage driver works
    if ! test_docker_storage; then
        echo "⚠️ Current Docker storage not working, reconfiguring..."
        configure_docker_storage "fuse-overlayfs"
        if ! test_docker_storage; then
            echo "⚠️ fuse-overlayfs failed, falling back to vfs driver"
            configure_docker_storage "vfs"
            if ! test_docker_storage; then
                echo "❌ All storage drivers failed"
                exit 1
            fi
        fi
    fi
fi

echo "ℹ️ Docker storage driver: $(docker info --format '{{.Driver}}')"

# Install Docker Compose plugin
if ! docker compose version &> /dev/null; then
    echo "🐳 Installing Docker Compose plugin..."
    apt-get install -y docker-compose-plugin
else
    echo "✅ Docker Compose already installed"
fi

# Install Caddy
if ! command -v caddy &> /dev/null; then
    echo "🌐 Installing Caddy..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install -y caddy
    systemctl enable caddy
else
    echo "✅ Caddy already installed"
fi

# Create app directories
echo "📁 Creating app directories..."
mkdir -p /opt/wordpress/{scripts,backups,config}
mkdir -p /var/log/wordpress

# Copy scripts from deployment source
echo "📋 Copying scripts..."
cp -r /tmp/app-source/scripts/* /opt/wordpress/scripts/ 2>/dev/null || true
chmod +x /opt/wordpress/scripts/*.sh 2>/dev/null || true

# Copy docker-compose.yaml
cp /tmp/app-source/docker-compose.yaml /opt/wordpress/

# Load environment variables
if [ -f /tmp/app-source/.env ]; then
    cp /tmp/app-source/.env /opt/wordpress/.env
fi

# Generate passwords if not set
cd /opt/wordpress
if [ -f .env ]; then
    source .env
fi

if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(pwgen -s 32 1)
    echo "DB_PASSWORD=$DB_PASSWORD" >> /opt/wordpress/.env
    echo "🔐 Generated DB_PASSWORD"
fi

if [ -z "$DB_ROOT_PASSWORD" ]; then
    DB_ROOT_PASSWORD=$(pwgen -s 32 1)
    echo "DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD" >> /opt/wordpress/.env
    echo "🔐 Generated DB_ROOT_PASSWORD"
fi

# Set domain from tfgrid-compose variable or .env
DOMAIN="${TFGRID_DOMAIN:-${DOMAIN:-localhost}}"
SSL_EMAIL="${TFGRID_SSL_EMAIL:-${SSL_EMAIL:-}}"

# Update .env with final domain
grep -q "^DOMAIN=" /opt/wordpress/.env && \
    sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" /opt/wordpress/.env || \
    echo "DOMAIN=$DOMAIN" >> /opt/wordpress/.env

echo "✅ Setup complete"
echo "📁 App directory: /opt/wordpress"
echo "🌐 Domain: $DOMAIN"
