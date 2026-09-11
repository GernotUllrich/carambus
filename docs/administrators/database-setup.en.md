# 🗄️ **Database Setup for Developers**

This document describes how to set up a development database for a Carambus scenario.

The database is called `<scenario>_development` (e.g. `carambus_bcw_development`). What counts is
`database:` in the scenario checkout's `config/database.yml` or `database_name` in
`carambus_data/scenarios/<scenario>/config.yml`.

## 🚀 **Quick Start (Recommended)**

### **Option 1: Via Scenario Management**

The regular path, from any up-to-date carambus checkout:

```bash
bin/rails "scenario:prepare_development[<scenario>,development]"
```

The task derives `<scenario>_development` from `carambus_api_development` (template via `createdb --template`)
and then resets the sequences for local data.

!!! warning "Prerequisites and side effects"
    - **SSH access to the Authority:** If `carambus_api_development` is missing or older than the
      Authority's production, the task fetches it via SSH as `www-data` from `api.carambus.de`. Currently
      only the Carambus operators have this access.
    - **Replaces `carambus_api_development`:** If the Authority has newer data, the local
      `carambus_api_development` is backed up, dropped and rebuilt; the backup is deleted afterwards. This
      affects every checkout using the same database.
    - **Replaces `<scenario>_development`:** An existing scenario database is dropped and recreated. If it
      contains local data (IDs from 50,000,000), the task aborts unless `FORCE=true` is set.

### **Option 2: Import a Database Dump**

Dumps are created and stored in a fixed place by the scenario tasks:

```bash
# Create a dump: carambus_data/scenarios/<scenario>/database_dumps/<scenario>_<env>_<YYYYMMDD_HHMMSS>.sql.gz
bin/rails "scenario:create_database_dump[<scenario>,development]"

# Restore the latest dump of this scenario (drops the target database first)
bin/rails "scenario:restore_database_dump[<scenario>,development]"
```

Importing by hand:

```bash
createdb <scenario>_development
gunzip -c /path/to/<file>.sql.gz | psql <scenario>_development
```

**Expected messages (can be ignored)**
```
ERROR: role "www_data" does not exist
invalid command \restrict
invalid command \unrestrict
ERROR: relation "table_name" already exists
ERROR: multiple primary keys for table "table_name" are not allowed
ERROR: relation "index_name" already exists
ERROR: constraint "constraint_name" for relation "table_name" already exists
ERROR: duplicate key value violates unique constraint "ar_internal_metadata_pkey"
```

The first three come from Authority dumps: the role `www_data` does not exist locally, and a newer
`pg_dump` writes meta-commands that an older local `psql` skips. Both also appear during
`scenario:prepare_development`; the task still reports success. The others occur when the database was
already partially initialized.

### **Option 3: Empty Database (Schema Only)**

```bash
bin/rails db:create
bin/rails db:migrate
```

The database then contains only the schema, **no master data**. `db:seed` creates nothing
(`db/seeds.rb` has no executable code). For a working instance use option 1 or 2.

## 🔧 **Detailed Guide**

### **Prerequisites**

- PostgreSQL is installed and running
- `createdb` and `psql` commands are available
- For option 1: SSH access to the Authority (see above) or an up-to-date local `carambus_api_development`
- For option 2: a dump under `carambus_data/scenarios/<scenario>/database_dumps/`

### **Check the Dump File**

```bash
# Available dumps
ls -lh ~/DEV/carambus/carambus_data/scenarios/<scenario>/database_dumps/

# Show first lines
gunzip -c /path/to/<file>.sql.gz | head -20
```

### **Create Database**

```bash
# Create new database
createdb <scenario>_development

# Or with specific parameters
createdb -h localhost -U username <scenario>_development
```

### **Import Dump**

```bash
# Simple import
gunzip -c /path/to/<file>.sql.gz | psql -d <scenario>_development

# With specific parameters
gunzip -c /path/to/<file>.sql.gz | psql -h localhost -U username -d <scenario>_development
```

### **Monitor Import**

```bash
# Test database connection
psql -d <scenario>_development -c "SELECT version();"
psql -d <scenario>_development -c "\dt"
```

## 🚨 **Troubleshooting**

### **Common Problems**

1. **Permission errors**
   ```bash
   # Check PostgreSQL users
   sudo -u postgres psql -c "\du"
   
   # Create user if needed
   sudo -u postgres createuser --interactive username
   ```

2. **Database already exists**
   ```bash
   # Drop and recreate database
   dropdb <scenario>_development
   createdb <scenario>_development
   ```

3. **Import fails**
   ```bash
   # Filter errors from the import
   gunzip -c /path/to/<file>.sql.gz | psql -d <scenario>_development 2>&1 | grep -i error
   ```

### **Verification**

After import, you should see the following tables:

```bash
psql -d <scenario>_development -c "\dt" | grep -E "(users|clubs|tournaments|leagues)"
```

## 📚 **Further Resources**

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Rails Database Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [Carambus Developer Guide](../developers/developer-guide.md)
- [Installation Overview](installation-overview.md)

---

**Tip**: For development, use a database derived from the Authority (option 1 or 2); only it contains the global master data and the current schema.
