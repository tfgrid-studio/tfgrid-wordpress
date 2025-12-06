#!/usr/bin/env bash
# TFGrid WordPress - WP-CLI Script
# Runs WP-CLI commands inside the WordPress container

if [ $# -eq 0 ]; then
    echo "Usage: wp-cli.sh <command>"
    echo ""
    echo "Examples:"
    echo "  wp-cli.sh core version"
    echo "  wp-cli.sh plugin list"
    echo "  wp-cli.sh user list"
    echo "  wp-cli.sh cache flush"
    exit 1
fi

# Run WP-CLI command
docker exec -it wordpress wp --allow-root "$@"
