#!/usr/bin/env bash
# TFGrid WordPress - Restore Script
# Restores WordPress from backup

set -e

BACKUP_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup)
            BACKUP_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Error: No backup file specified"
    echo "Usage: restore.sh --backup /path/to/backup.tar.gz"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️ WARNING: This will overwrite your current WordPress installation!"
echo "   Backup file: $BACKUP_FILE"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

TEMP_DIR=$(mktemp -d)

echo "📦 Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Load environment
cd /opt/wordpress
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Stop WordPress container (keep database running)
echo "🛑 Stopping WordPress container..."
docker stop wordpress || true

# Restore database
if [ -f "$TEMP_DIR/database.sql" ]; then
    echo "💾 Restoring database..."
    docker exec -i wordpress-db mysql \
        -u wordpress \
        -p"$DB_PASSWORD" \
        wordpress < "$TEMP_DIR/database.sql"
    echo "   Database restored"
fi

# Restore WordPress files
if [ -f "$TEMP_DIR/wordpress_files.tar.gz" ]; then
    echo "📁 Restoring WordPress files..."
    # Clear existing data
    docker run --rm \
        -v wordpress_data:/data \
        alpine sh -c "rm -rf /data/* /data/.*" 2>/dev/null || true
    # Extract backup
    docker run --rm \
        -v wordpress_data:/data \
        -v "$TEMP_DIR":/backup:ro \
        alpine tar xzf /backup/wordpress_files.tar.gz -C /data
    echo "   Files restored"
fi

# Restore configuration if present
if [ -f "$TEMP_DIR/env.backup" ]; then
    echo "⚙️ Restoring configuration..."
    cp "$TEMP_DIR/env.backup" /opt/wordpress/.env
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Start WordPress container
echo "🚀 Starting WordPress container..."
docker start wordpress

# Wait for WordPress to be ready
echo "⏳ Waiting for WordPress to start..."
sleep 10

echo ""
echo "✅ Restore complete!"
echo ""
echo "Please verify your site is working correctly."
echo "You may need to update the site URL if the domain has changed."
