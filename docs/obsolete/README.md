# Obsolete Documentation

This directory contains documentation for systems and features that are no longer active or have been replaced by newer implementations.

## ⚠️ Warning

**DO NOT FOLLOW** these guides for new deployments. They are kept here for historical reference only.

## Archived Documentation

### enhanced_mode_system.de.md

**Archived:** 2025-10-12  
**Original Purpose:** Documentation for the Mode Management System  
**Status:** ❌ Obsolete - System completely removed

**Reason for Obsolescence:**

The Mode Management System (`mode:api`, `mode:local`, `mode:web_client`) has been completely replaced by the **Scenario Management System**.

**What Was It?**

The Enhanced Mode System allowed switching between deployment configurations using Rake tasks with many parameters:
- Complex parameter passing via `MODE_*` environment variables
- Manual configuration file generation
- No version control for deployment states
- Difficult testing and rollback

**Modern Replacement: Scenario Management**

All functionality is now handled by the Scenario Management System:

📚 **Current Documentation:**
- [Scenario Management Guide](../scenario_management.md) - Complete replacement system
- [Deployment Workflow](../deployment_workflow.md) - Modern deployment process
- [Developer Rake Tasks](../entwickler-rake-tasks-debugging.md) - Current task reference

🚀 **Quick Migration:**

```bash
# OLD (obsolete):
bundle exec rails 'mode:local' MODE_LOCATION_ID=5101 MODE_API_URL=https://newapi.carambus.de/

# NEW (current):
rake scenario:deploy[carambus_location_5101,production]
```

**Benefits of Scenario System:**
- Configuration as code (YAML files)
- Version controlled deployment states
- Atomic deployments with automatic rollback
- Local data preservation
- Built-in testing and validation
- Remote deployment via SSH
- Automatic service management

---

## Why Keep Obsolete Docs?

These documents are retained for:
- Historical reference
- Understanding system evolution
- Migration support for legacy deployments
- Audit trails for configuration decisions

If you encounter a production system still using mode tasks, **migrate immediately** to the Scenario Management System.

---

**Last Updated:** 2025-10-12  
**Maintainer:** Development Team

