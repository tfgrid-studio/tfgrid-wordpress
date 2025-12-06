# TFGrid WordPress

Self-hosted WordPress with Caddy and MariaDB on ThreeFold Grid.

## Overview

Deploy a production-ready WordPress installation with:
- **WordPress** - Latest official Docker image
- **MariaDB** - Database backend with health checks
- **Caddy** - Automatic HTTPS with Let's Encrypt

## Quick Start

```bash
# Deploy with tfgrid-compose
tfgrid-compose up tfgrid-wordpress

# Or manually:
cp .env.example .env
# Edit .env with your domain
nano .env

# Deploy
tfgrid-compose up .
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Public domain for WordPress |
| `SSL_EMAIL` | No | Email for Let's Encrypt |
| `DB_PASSWORD` | No | MariaDB password (auto-generated) |
| `DB_ROOT_PASSWORD` | No | MariaDB root password (auto-generated) |

### Example .env

```bash
DOMAIN=blog.example.com
SSL_EMAIL=admin@example.com
```

## Commands

| Command | Description |
|---------|-------------|
| `tfgrid-compose backup` | Create full backup |
| `tfgrid-compose restore --backup <file>` | Restore from backup |
| `tfgrid-compose list-backups` | List available backups |
| `tfgrid-compose logs [service]` | View logs |
| `tfgrid-compose shell` | Open container shell |
| `tfgrid-compose wp <command>` | Run WP-CLI commands |
| `tfgrid-compose restart` | Restart services |

## Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 core | 2 cores |
| Memory | 1 GB | 2 GB |
| Disk | 20 GB | 50 GB |

## Architecture

```
┌─────────────┐     ┌───────────────┐     ┌──────────────┐
│   Internet  │────▶│  Caddy :443   │────▶│  WordPress   │
│             │     │  (auto-SSL)   │     │  :8080       │
└─────────────┘     └───────────────┘     └──────┬───────┘
                                                 │
                                          ┌──────▼───────┐
                                          │   MariaDB    │
                                          │   :3306      │
                                          └──────────────┘
```

## Backup & Restore

### Create Backup
```bash
tfgrid-compose backup
# Output: /opt/wordpress/backups/wordpress_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Restore from Backup
```bash
tfgrid-compose restore --backup /path/to/backup.tar.gz
```

### Backup Contents
- Database dump (SQL)
- WordPress files (wp-content, themes, plugins, uploads)
- Configuration files

## Troubleshooting

### Check Service Status
```bash
tfgrid-compose healthcheck
```

### View Logs
```bash
# All logs
tfgrid-compose logs

# Specific service
tfgrid-compose logs wordpress
tfgrid-compose logs db
tfgrid-compose logs caddy
```

### Common Issues

**WordPress shows "Error establishing database connection"**
- Check MariaDB is running: `docker ps`
- Check database credentials in `.env`

**SSL certificate not working**
- Ensure domain DNS points to server IP
- Check Caddy logs: `tfgrid-compose logs caddy`

## License

Apache 2.0