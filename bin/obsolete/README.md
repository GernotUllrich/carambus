# Obsolete Scripts

This folder contains scripts that are no longer used in the current Carambus system but are kept for reference.

## Contents

### Mode Management Scripts (Obsolete)
- `console-api.sh` - Console for API mode
- `console-local.sh` - Console for local mode
- `console-production.sh` - Console for production mode
- `debug-production.sh` - Debug helper for production

**Obsoleted:** 2025-10-12  
**Reason:** Replaced by scenario-based deployment system

**Modern alternatives:**
```bash
# Direct Rails console access
cd carambus_<scenario>
bundle exec rails console

# Or on production server
ssh www-data@server
cd /var/www/carambus_<scenario>
RAILS_ENV=production bundle exec rails console
```

See: `console-scripts.obsolete.README` for details

### Client Installation Scripts (Obsolete)
- `install-scoreboard-client.sh` - Old client installation

**Obsoleted:** 2025-10-12  
**Reason:** Replaced by scenario-based `install-client-only.sh`

**Modern alternative:**
```bash
bin/install-client-only.sh <scenario_name> <client_ip>
```

See: `install-scoreboard-client.sh.obsolete.README` for details

### Database Migration Scripts (Obsolete)
- `api_from_api2_db.sh` - Old database migration

**Obsoleted:** Earlier  
**Reason:** Migration completed, specific to carambus2 → carambus3 transition

## Can These Be Deleted?

Yes, after 3-6 months if no one reports needing them. They serve as:
- Reference for the old system
- Documentation of migration path
- Fallback if issues arise

## Migration History

1. **Mode Management → Scenarios** (2025-10-12)
   - Old: `:api`, `:local`, `:production` modes
   - New: Scenario-based configuration via `config.yml`

2. **Client Installation** (2025-10-12)
   - Old: `install-scoreboard-client.sh` (location_id based)
   - New: `install-client-only.sh` (scenario-based)

3. **Database Migration** (Earlier)
   - carambus2 → carambus3 migration completed
   - Scripts no longer needed

## See Also

- `../install-client-only.sh` - Current client installation
- `../setup-raspi-table-client.sh` - Full Raspi setup
- `../deploy-scenario.sh` - Scenario deployment
- `../../lib/tasks/scenarios.rake` - Scenario management
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_data/CARAMBUS_BASE_IMPLEMENTATION.md` - Current architecture
