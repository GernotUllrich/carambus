# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- New utility script `bin/check-database-states.sh` for comprehensive database state analysis
  - Compares database states across local, production, and API server environments
  - Checks Version IDs, table_locals, and tournament_locals
  - Warns about unbumped IDs (< 50,000,000)
  - Shows ID ranges and local data statistics
  - Usage: `./bin/check-database-states.sh <scenario_name>`

- New utility script `bin/puma-wrapper.sh` for systemd service management
  - Properly initializes rbenv for Puma service
  - Changes to correct deployment directory
  - Usage: `puma-wrapper.sh <basename>` or via `PUMA_BASENAME` environment variable

### Changed
- Updated Raspberry Pi client setup for Debian Trixie compatibility
  - Changed from `chromium-browser` to `chromium` package (newer Raspberry Pi OS versions)
  - Updated executable path from `/usr/bin/chromium-browser` to `/usr/bin/chromium`
  - Fixes installation error: "Package chromium-browser is not available"

### Fixed
- Fixed chromium package installation on newer Raspberry Pi OS (Debian Trixie/Bookworm)
- Ensured compatibility with both old (Debian Bullseye) and new Raspberry Pi OS versions

## [2025-10-17] - Branch Integration

### Merged
- Integrated `scorebord_menu` branch into master
  - Scoreboard menu improvements
  - NetworkManager support in setup script
  - Multi-WLAN support features
  - Automatic detection of dhcpcd vs. NetworkManager

### Compatibility
- ✅ Raspberry Pi OS (Debian Bullseye) - maintains backward compatibility
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - primary support
- ✅ dhcpcd-based network configuration
- ✅ NetworkManager-based configuration

---

## Deployment Notes

### Raspberry Pi Setup on Debian Trixie
```bash
sh bin/setup-raspi-table-client.sh carambus_bcw <current_ip> \
  <ssid> <password> <static_ip> <table_number> [ssh_port] [ssh_user] [server_ip]
```

The script automatically detects:
- Correct chromium package name
- Network management system in use (dhcpcd/NetworkManager)
- Configures WLAN and static IP accordingly

