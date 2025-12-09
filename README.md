# TFGrid WordPress

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/tfgrid-studio/tfgrid-wordpress)](https://github.com/tfgrid-studio/tfgrid-wordpress/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/tfgrid-studio/tfgrid-wordpress)](https://github.com/tfgrid-studio/tfgrid-wordpress/issues)

Self-hosted WordPress with Caddy and MariaDB on ThreeFold Grid. 

## Overview

Deploy a production-ready WordPress installation with:
- **WordPress** - Latest official Docker image
- **MariaDB** - Database backend with health checks
- **Caddy** - Automatic HTTPS with Let's Encrypt
- **Automatic DNS** - Optional DNS A record creation (Name.com, Namecheap, Cloudflare)

## Quick Start

### Basic Deployment (Interactive)

The easiest way to deploy - answers questions interactively:

```bash
tfgrid-compose up tfgrid-wordpress -i
```

This will prompt you for:
1. Domain name
2. DNS provider (optional automatic setup)
3. WordPress settings
4. Resource allocation
5. Node selection

### One-Line Deployment

Deploy with all settings on the command line:

```bash
tfgrid-compose up tfgrid-wordpress \
  --env DOMAIN=blog.example.com \
  --env SSL_EMAIL=admin@example.com \
  --env WP_SITE_TITLE="My Blog" \
  --env WP_ADMIN_EMAIL=admin@example.com
```

### Full Deployment Example

Complete deployment with DNS automation and all options:

```bash
# With Name.com DNS automation (recommended - fully automated)
tfgrid-compose up tfgrid-wordpress \
  --env DOMAIN=blog.example.com \
  --env SSL_EMAIL=admin@example.com \
  --env DNS_PROVIDER=name.com \
  --env NAMECOM_USERNAME=myuser \
  --env NAMECOM_API_TOKEN=your-api-token \
  --env WP_SITE_TITLE="My Awesome Blog" \
  --env WP_ADMIN_USER=myadmin \
  --env WP_ADMIN_EMAIL=admin@example.com \
  --env PHP_MEMORY_LIMIT=512M \
  --env PHP_UPLOAD_MAX=128M \
  --cpu 2 \
  --memory 4096 \
  --disk 100

# With Cloudflare DNS automation (recommended - fully automated)
tfgrid-compose up tfgrid-wordpress \
  --env DOMAIN=blog.example.com \
  --env DNS_PROVIDER=cloudflare \
  --env CLOUDFLARE_API_TOKEN=your-cf-token \
  --env WP_SITE_TITLE="My Blog"

# With GoDaddy DNS automation
tfgrid-compose up tfgrid-wordpress \
  --env DOMAIN=blog.example.com \
  --env DNS_PROVIDER=godaddy \
  --env GODADDY_API_KEY=your-api-key \
  --env GODADDY_API_SECRET=your-api-secret \
  --env WP_SITE_TITLE="My Blog"
```

## Configuration

### Environment Variables

#### Domain & SSL

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | **Yes** | - | Public domain for WordPress |
| `SSL_EMAIL` | No | - | Email for Let's Encrypt certificates |

#### DNS Automation

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DNS_PROVIDER` | No | `manual` | DNS provider: `manual`, `name.com`, `cloudflare`, `godaddy` |
| `NAMECOM_USERNAME` | If name.com | - | Name.com username |
| `NAMECOM_API_TOKEN` | If name.com | - | Name.com API token |
| `CLOUDFLARE_API_TOKEN` | If cloudflare | - | Cloudflare API token |
| `GODADDY_API_KEY` | If godaddy | - | GoDaddy API key |
| `GODADDY_API_SECRET` | If godaddy | - | GoDaddy API secret |

#### WordPress Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WP_ADMIN_USER` | No | `admin` | WordPress admin username |
| `WP_ADMIN_EMAIL` | No | - | WordPress admin email |
| `WP_SITE_TITLE` | No | `My WordPress Site` | Site title |
| `WP_LOCALE` | No | `en_US` | Language/locale code |

#### Performance

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | No | `256M` | PHP memory limit |
| `PHP_UPLOAD_MAX` | No | `64M` | Maximum upload file size |
| `WP_DEBUG` | No | `false` | Enable debug mode |

#### Database

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_PASSWORD` | No | auto-generated | MariaDB password |
| `DB_ROOT_PASSWORD` | No | auto-generated | MariaDB root password |

#### Backup

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BACKUP_RETENTION_DAYS` | No | `30` | Days to keep backups |

## DNS Setup

### Automatic DNS (Recommended)

Use `-i` interactive mode or set `DNS_PROVIDER` to automatically create DNS A records:

```bash
# Interactive - will prompt for credentials
tfgrid-compose up tfgrid-wordpress -i

# Or specify provider and credentials
tfgrid-compose up tfgrid-wordpress \
  --env DOMAIN=blog.example.com \
  --env DNS_PROVIDER=cloudflare \
  --env CLOUDFLARE_API_TOKEN=your-token
```

### Manual DNS

If using `DNS_PROVIDER=manual` (default), you'll need to:

1. Deploy the app to get the server IP
2. Create an A record with your DNS provider:
   - **Name**: `blog` (or `@` for root domain)
   - **Type**: `A`
   - **Value**: `<server-ip>`
   - **TTL**: `300`
3. Wait 1-5 minutes for propagation

### Getting DNS API Credentials

#### Name.com
1. Log in to [Name.com](https://www.name.com)
2. Go to Account → API Token
3. Generate a new token

#### Namecheap
⚠️ **Note**: Namecheap requires IP whitelisting before API calls work.

1. Log in to [Namecheap](https://www.namecheap.com)
2. Go to Profile → Tools → API Access
3. Enable API access
4. **Whitelist your current IP** (required before API works)
5. Copy API Key

Your IP must be whitelisted before running `tfgrid-compose up -i`. The interactive mode will show your current IP and ask you to confirm it's whitelisted.

#### Cloudflare
1. Log in to [Cloudflare](https://dash.cloudflare.com)
2. Go to My Profile → API Tokens
3. Create token with "Edit zone DNS" permission

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

## Support

- **📚 Documentation:** [docs.tfgrid.studio](https://docs.tfgrid.studio)
- **🐛 Issues:** [GitHub Issues](https://github.com/tfgrid-studio/tfgrid-wordpress/issues)
- **💬 Discussions:** [GitHub Discussions](https://github.com/orgs/tfgrid-studio/discussions)
- **📧 Contact:** [tfgrid.studio/contact](https://tfgrid.studio/contact)

## License

Apache 2.0