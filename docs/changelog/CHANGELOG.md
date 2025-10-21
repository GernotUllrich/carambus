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
  - Static IP automatically from Database (table_locals.ip_address)
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

- **Sidebar Behavior** improved for Scoreboard
  - Checks both `current_user` and `Current.user` for auto-login
  - Sidebar always starts collapsed with `sb_state` parameter
  - JavaScript enforces collapsed state for scoreboard URLs
  - Correct `sidebar-collapsed` CSS class

- **Raspberry Pi Client Setup** for Debian Trixie compatibility
  - Switched from `chromium-browser` to `chromium` package (newer Raspberry Pi OS versions)
  - Executable path updated from `/usr/bin/chromium-browser` to `/usr/bin/chromium`
  - Fixes installation error: "Package chromium-browser is not available"

- **Network Configuration** made smarter
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
  - `locale` parameter preserved during redirect
  - Scoreboard now always starts in German

- **Local Data Migration**
  - Schema-compatible backup for Carambus2 migration
  - Correct `region_id` and `global_context` columns
  - Automatic role conversion (String → Integer)

- Chromium package installation on newer Raspberry Pi OS (Debian Trixie/Bookworm)
- Compatibility with old (Debian Bullseye) and new Raspberry Pi OS versions ensured
- NetworkManager-based systems are now correctly detected and configured

## [2025-10-17] - Branch Integration

### Merged
- Branch `scorebord_menu` successfully integrated into master

### Changed
- **Game History View** improved
  - Now displays complete history for location
  - Correct ordering
  - Efficient database queries
  - Clear presentation

## [2025-10-11] - Release

### Added
- **Comprehensive Documentation System** using MkDocs
  - Structured documentation with clear navigation
  - German and English versions maintained in parallel
  - Separate documentation for different user groups (administrators, developers, users)
  - Automatic generation via `mkdocs serve` and `mkdocs build`

- **Region Tagging System**
  - Support for region_id across all tournament-relevant models
  - Enables clean data separation between regions
  - Improves performance through targeted filtering
  - Documented migration and cleanup scripts

- **Enhanced Mode System**
  - Separation of table_mode and game_mode
  - Support for different game variants
  - Clear state management
  - New transitions and validations

### Changed
- **Directory Structure** reorganized
  - Centralized documentation in `/docs`
  - Separate directories for different documentation types
  - Obsolete documentation moved to `/docs/obsolete`

- **Documentation Quality**
  - Redundancy removed
  - Content updated and expanded
  - Navigation structure improved
  - Better cross-references

### Fixed
- Region tagging cleanup completed for all models
- Mode system inconsistencies resolved

## [Earlier Versions]

For earlier version history, see Git commit history.
