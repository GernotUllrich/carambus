# Obsolete Docker Configurations

This directory contains Docker Compose configurations that are no longer used in production.

## ⚠️ Warning

**DO NOT USE** these configurations for new deployments. They are kept here for historical reference only.

## Archived Configurations

### docker-compose.mode.api.yml
### docker-compose.mode.local.yml

**Archived:** 2025-10-12  
**Reason:** Part of obsolete Mode Management System

**Original Purpose:**
These Docker Compose files were used with the Mode Management System to configure:
- `mode.api.yml` - API server deployment configuration
- `mode.local.yml` - Local Raspberry Pi server configuration

**Why Obsolete?**

The Mode Management System has been completely replaced by the **Scenario Management System**, which:
- Uses version-controlled YAML scenario files
- Provides atomic deployments
- Includes comprehensive testing
- Supports remote SSH deployment
- Handles local data preservation

**Modern Approach:**

Docker is now primarily used for:
1. **Development environments** - See `docker-compose.development.yml`
2. **Testing environments** - See individual test configurations
3. **Production uses Capistrano** or **Scenario-based deployment** instead

**Replacement Path:**

For production deployments, use:
```bash
# Scenario-based deployment (recommended)
rake scenario:deploy[scenario_name,target_environment]

# Or Capistrano (for API server)
cap production deploy
```

**Related Obsolete Files:**
- `lib/tasks/obsolete/mode.rake` - Mode management Rake tasks
- `docs/obsolete/enhanced_mode_system.de.md` - Mode system documentation

---

**Last Updated:** 2025-10-12  
**Maintainer:** Development Team

