# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🇩🇪 **German Version**: [CHANGELOG.de.md](CHANGELOG.de.md)

## [Unreleased]

### Added
- **Carambus2 Migration Feature**
  - Automatic schema migration from Carambus2 to current version
  - Detects old schema structure (without region_id, global_context)
  - Automatically converts during `prepare_development`
  - Creates schema-compatible backup before migration
  - Documented in scenario_management.en.md

- **Simplified Table Client Setup** (`bin/setup-table-raspi.sh`)
  - Only 3 parameters needed: scenario, current_ip, table_name
  - Club WLAN from `config.yml` (production.network.club_wlan)
  - Dev WLAN from `~/.carambus_config` (CARAMBUS_DEV_WLAN_*)
  - Static IP automatically from database (table_locals.ip_address)
  - Multi-WLAN with automatic fallback

- **Database Analysis Tool** (`bin/check-database-states.sh`)
  - Comprehensive analysis of database states across Local, Production and API Server
  - Compares version IDs, table_locals and tournament_locals
  - Warns about unbumped IDs (< 50,000,000)
  - Shows ID ranges and local data statistics
  - Usage: `./bin/check-database-states.sh <scenario_name>`

- **Puma Service Wrapper** (`bin/puma-wrapper.sh`)
  - Correct rbenv initialization for Puma systemd service
  - Changes to correct deployment directory
  - Usage: `puma-wrapper.sh <basename>` or via `PUMA_BASENAME` environment variable

### Changed
- **Scoreboard Client Optimizations**
  - Chromium --kiosk mode for clean UI (no warnings, no URL bar)
  - Startup time reduced from ~45s to ~18s (60% faster)
  - Conditional Puma wait time only for local servers
  - Simplified URL logic for remote clients
  - German as default language (`locale=de` parameter)

- **Sidebar Behavior** improved for scoreboard
  - Checks both `current_user` and `Current.user` for auto-login
  - Sidebar always starts closed with `sb_state` parameter
  - JavaScript enforces collapsed state for scoreboard URLs
  - Correct `sidebar-collapsed` CSS class

- **Raspberry Pi Client Setup** for Debian Trixie compatibility
  - Changed from `chromium-browser` to `chromium` package (newer Raspberry Pi OS versions)
  - Executable path updated from `/usr/bin/chromium-browser` to `/usr/bin/chromium`
  - Fixes installation error: "Package chromium-browser is not available"

- **Network Configuration** made more intelligent
  - Automatic detection of dhcpcd vs. NetworkManager
  - Support for both network management systems
  - Automatic nmcli configuration for NetworkManager systems

### Fixed
- **Chromium Sandbox Warning** on Raspberry Pi clients
  - Replaced `--no-sandbox` with `--disable-setuid-sandbox`
  - No more "unsupported command-line flag" warning
  - Additional flags: `--disable-infobars`, `--noerrdialogs`

- **Scoreboard URL** corrected
  - Explicit `/scoreboard` route for auto-login
  - `locale` parameter retained on redirect
  - Scoreboard now always starts in German

- **Local Data Migration**
  - Schema-compatible backup for Carambus2 migration
  - Correct `region_id` and `global_context` columns
  - Automatic role conversion (String → Integer)

- Chromium package installation on newer Raspberry Pi OS (Debian Trixie/Bookworm)
- Compatibility with old (Debian Bullseye) and new Raspberry Pi OS versions ensured
- NetworkManager-based systems now correctly detected and configured

## [2025-10-17] - Branch Integration

### Merged
- Branch `scorebord_menu` successfully integrated into master
  - Scoreboard menu improvements
  - NetworkManager support in setup script
  - Multi-WLAN support features
  - Automatic detection of dhcpcd vs. NetworkManager

### Compatibility
- ✅ Raspberry Pi OS (Debian Bullseye) - Backward compatibility maintained
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primary support
- ✅ dhcpcd-based network configuration
- ✅ NetworkManager-based configuration

---

## [7.2.0] - 2024-12-19

### Added
- Rails 7.2 upgrade
- Hotwire/Stimulus integration
- Action Cable for real-time updates
- Administrate admin interface
- Devise for authentication
- Pundit for authorization

### Changed
- Ruby 3.2+ support
- PostgreSQL as main database
- Redis for caching and Action Cable
- Puma as web server
- Nginx as reverse proxy

### Fixed
- Performance optimizations
- Security improvements
- Code quality improved

## [7.1.0] - 2024-06-15

### Added
- Tournament management system
- Player management
- League management
- Live scoreboards
- Real-time updates

### Changed
- Modern web interface
- Responsive design
- Multi-language (German/English)
- API for integrations

### Fixed
- Stability improved
- User-friendliness increased

## [7.0.0] - 2024-01-10

### Added
- Basic Carambus functionality
- Billiards tournament management
- Club management
- User management

### Changed
- Ruby on Rails foundation
- PostgreSQL database
- Modern web technologies

### Fixed
- First stable version
- Basic functions implemented

---

## Deployment Notes

### Raspberry Pi Setup on Debian Trixie/Bookworm

```bash
sh bin/setup-raspi-table-client.sh carambus_bcw <current_ip> \
  <ssid> <password> <static_ip> <table_number> [ssh_port] [ssh_user] [server_ip]
```

The script automatically detects:
- The correct Chromium package name
- The network management system being used (dhcpcd/NetworkManager)
- Configures WLAN and static IP accordingly

### Database Analysis

To check database states before/after deployments:

```bash
./bin/check-database-states.sh carambus_bcw
```

---

**Note**: All versions before 7.0.0 are legacy versions and are no longer supported.

**Migration**: For existing installations see [Migration Guide](../INSTALLATION/QUICKSTART.md#migration-von-bestehenden-installationen).

---

## Historical Notes

### Docker Approach (Abandoned)

Earlier versions experimented with a Docker-based deployment approach. This was abandoned in favor of the current Capistrano-based deployment strategy. Docker configurations remain in the repository for reference purposes but are no longer the recommended deployment method.

**Current Deployment Approach:**
- Capistrano for production deployments
- Systemd services for Puma
- Nginx as reverse proxy
- Direct server installation (no containers)

For details see [Deployment Workflow](../developers/deployment-workflow.en.md).



