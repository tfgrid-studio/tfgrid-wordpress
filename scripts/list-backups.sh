#!/usr/bin/env bash
# TFGrid WordPress - List Backups Script

BACKUP_DIR="/opt/wordpress/backups"

echo "📦 WordPress Backups"
echo "   Location: $BACKUP_DIR"
echo ""

if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "No backups found."
    echo ""
    echo "Create a backup with: tfgrid-compose backup"
    exit 0
fi

echo "Available backups:"
echo ""
printf "%-45s %10s %s\n" "FILENAME" "SIZE" "DATE"
printf "%-45s %10s %s\n" "--------" "----" "----"

for backup in "$BACKUP_DIR"/*.tar.gz; do
    if [ -f "$backup" ]; then
        FILENAME=$(basename "$backup")
        SIZE=$(du -h "$backup" | cut -f1)
        DATE=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        printf "%-45s %10s %s\n" "$FILENAME" "$SIZE" "$DATE"
    fi
done

echo ""
echo "To restore: tfgrid-compose restore --backup <filename>"
