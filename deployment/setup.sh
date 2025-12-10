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
    
    # Stop docker first
    systemctl stop docker 2>/dev/null || true
    sleep 1
    
    # Clear old storage data to prevent conflicts
    rm -rf /var/lib/docker/* 2>/dev/null || true
    
    # Write new config
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "storage-driver": "$driver"
}
EOF
    
    # Restart docker with new config
    systemctl start docker
    sleep 3
    
    # Verify docker is running
    if ! systemctl is-active --quiet docker; then
        echo "⚠️ Docker failed to start with $driver driver"
        return 1
    fi
    echo "✅ Docker started with $driver driver"
    return 0
}

# Function to test Docker storage driver with an image that has whiteout files
test_docker_storage() {
	echo "🧪 Testing Docker storage driver..."

	# Use ubuntu:latest which has whiteout files that trigger overlay issues
	# hello-world and alpine are too simple
	local pull_output
	local run_output

	# First, try to pull the image
	if ! pull_output=$(docker pull ubuntu:latest 2>&1); then
		# If we see whiteout/overlay errors, this is a real storage-driver problem
		if echo "$pull_output" | grep -qi "whiteout"; then
			echo "⚠️ Storage driver failed: whiteout file error"
			echo "⚠️ Docker storage driver test failed"
			docker rmi ubuntu:latest >/dev/null 2>&1 || true
			return 1
		fi

		# Detect common registry/network connectivity issues and do NOT
		# treat them as storage-driver failures. The app will still
		# ultimately require registry access for its own images, but
		# we don't want to misclassify this as a driver problem.
		if echo "$pull_output" | grep -qiE "Client.Timeout|request canceled while waiting for connection|i/o timeout|no such host|temporary failure in name resolution|TLS handshake timeout|connection refused"; then
			echo "⚠️ Docker registry unreachable during storage driver test (network issue)"
			echo "⚠️ Skipping strict storage-driver validation but continuing with current driver"
			return 0
		fi

		# Unknown pull failure – treat as potential driver issue
		echo "⚠️ Storage driver failed: $pull_output"
		echo "⚠️ Docker storage driver test failed"
		docker rmi ubuntu:latest >/dev/null 2>&1 || true
		return 1
	fi

	# Image pulled successfully; now verify we can run a container
	if run_output=$(docker run --rm ubuntu:latest echo "Storage driver OK" 2>&1); then
		echo "✅ Docker storage driver working"
		docker rmi ubuntu:latest >/dev/null 2>&1 || true
		return 0
	else
		echo "⚠️ Docker run failed during storage driver test: $run_output"
		echo "⚠️ Docker storage driver test failed"
		docker rmi ubuntu:latest >/dev/null 2>&1 || true
		return 1
	fi
}

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
fi

# Always configure and test storage driver after Docker is available
# TFGrid VMs have filesystem limitations that prevent overlay2/fuse-overlayfs from working
echo "🔧 Configuring Docker storage driver for TFGrid compatibility..."

# Disable exit on error for driver testing - we handle failures manually
set +e

# First try fuse-overlayfs
driver_ok=false
if configure_docker_storage "fuse-overlayfs" && test_docker_storage; then
    driver_ok=true
else
    echo "⚠️ fuse-overlayfs failed, falling back to vfs driver"
    if configure_docker_storage "vfs" && test_docker_storage; then
        driver_ok=true
    fi
fi

# Re-enable exit on error
set -e

if [ "$driver_ok" != "true" ]; then
    echo "❌ All storage drivers failed"
    exit 1
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
