#!/usr/bin/env bash
# TFGrid WordPress - Backup Script
# Creates full backup of WordPress files and database

set -e

BACKUP_DIR="/opt/wordpress/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Set output file if not specified
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$BACKUP_DIR/wordpress_backup_$TIMESTAMP.tar.gz"
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"
TEMP_DIR=$(mktemp -d)

echo "📦 Creating WordPress backup..."
echo "   Output: $OUTPUT_FILE"

# Load environment for database credentials
cd /opt/wordpress
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Backup database
echo "💾 Backing up database..."
docker exec wordpress-db mysqldump \
    -u wordpress \
    -p"$DB_PASSWORD" \
    wordpress > "$TEMP_DIR/database.sql"
echo "   Database: $(du -h "$TEMP_DIR/database.sql" | cut -f1)"

# Backup WordPress files
echo "📁 Backing up WordPress files..."
docker run --rm \
    -v wordpress_data:/data:ro \
    -v "$TEMP_DIR":/backup \
    alpine tar czf /backup/wordpress_files.tar.gz -C /data .
echo "   Files: $(du -h "$TEMP_DIR/wordpress_files.tar.gz" | cut -f1)"

# Backup configuration
echo "⚙️ Backing up configuration..."
cp /opt/wordpress/.env "$TEMP_DIR/env.backup" 2>/dev/null || true
cp /opt/wordpress/docker-compose.yaml "$TEMP_DIR/" 2>/dev/null || true
cp /etc/caddy/Caddyfile "$TEMP_DIR/Caddyfile.backup" 2>/dev/null || true

# Create metadata
cat > "$TEMP_DIR/backup_info.json" <<EOF
{
    "created_at": "$(date -Iseconds)",
    "wordpress_version": "$(docker exec wordpress wp core version 2>/dev/null || echo 'unknown')",
    "database_size": "$(du -h "$TEMP_DIR/database.sql" | cut -f1)",
    "files_size": "$(du -h "$TEMP_DIR/wordpress_files.tar.gz" | cut -f1)",
    "hostname": "$(hostname)"
}
EOF

# Create final archive
echo "📦 Creating final archive..."
tar czf "$OUTPUT_FILE" -C "$TEMP_DIR" .

# Cleanup
rm -rf "$TEMP_DIR"

# Show result
FINAL_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo ""
echo "✅ Backup complete!"
echo "   File: $OUTPUT_FILE"
echo "   Size: $FINAL_SIZE"
echo ""
echo "To restore: tfgrid-compose restore --backup $OUTPUT_FILE"
