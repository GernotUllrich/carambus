# Obsolete Rake Tasks

This directory contains Rake task files that are no longer used in production and have been superseded by newer systems.

## ⚠️ Warning

**DO NOT USE** these tasks for production deployments or new development. They are kept here for historical reference only.

## Archived Tasks

### mode.rake (2,132 lines)

**Archived:** 2025-10-12  
**Reason:** Completely replaced by Scenario Management System

**Original Purpose:**
The mode system provided tasks to switch between different deployment configurations:
- `mode:api` - Configure as API server
- `mode:local` - Configure as local Raspberry Pi server
- `mode:web_client` - Configure as web client (BCW)

**Problems with Mode System:**
- Too complex to manage and maintain
- Required manual configuration file editing
- Difficult to test and debug
- No version control for configurations
- Hard to replicate exact deployment states

**Replacement: Scenario Management System**

The Scenario Management system completely replaces mode tasks with a superior approach:

```bash
# Instead of: rake mode:local [params...]
# Use:
rake scenario:deploy[scenario_name,target_environment]

# Example:
rake scenario:deploy[carambus_location_5101,production]
```

**Benefits of Scenario System:**
- ✅ Configuration stored as YAML scenarios under version control
- ✅ Atomic deployments with rollback capability
- ✅ Local data preservation (table_locals, tournament_locals)
- ✅ Complete test suite before deploying
- ✅ SSH-based remote deployment
- ✅ Automatic service restart and health checks
- ✅ Database sync with production data
- ✅ Asset precompilation included

**Migration Path:**

If you have old mode-based deployments:

1. **Document current configuration:**
   ```bash
   # Check current settings
   cat config/carambus.yml
   cat config/database.yml
   ```

2. **Create scenario file:**
   ```bash
   # Generate from template
   rake scenario:generate_config[your_location_name]
   ```

3. **Deploy with scenario:**
   ```bash
   rake scenario:deploy[your_location_name,production]
   ```

**Documentation:**
- [Scenario Management Guide](../../docs/scenario_management.de.md)
- [Deployment Workflow](../../docs/deployment_workflow.de.md)
- [Developer Rake Tasks](../../docs/entwickler-rake-tasks-debugging.de.md)

**Related Obsolete Files:**
- `docs/obsolete/enhanced_mode_system.de.md` - Mode system documentation
- `docker-trial/obsolete/docker-compose.mode.*.yml` - Mode Docker configs

---

**Last Updated:** 2025-10-12  
**Maintainer:** Development Team

