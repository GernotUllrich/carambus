# 🗄️ **Database Setup for Developers**

This document describes how to set up a new development database for Carambus.

## 🚀 **Quick Start (Recommended)**

### **Option 1: Import Database Dump**

1. **Obtain Database Dump**
   - From another developer on the team
   - From your local `carambus_api` folder
   - From the Team Lead

2. **Create Database and Import Dump**
   ```bash
   # Create database
   createdb carambus_development
   
   # Import dump
   psql -d carambus_development -f /path/to/your/dump.sql
   
   # Example:
   psql -d carambus_development -f tmp/carambus_api_development_20250813_230822.sql
   ```

3. **Expected Errors (can be ignored)**
   ```
   ERROR: relation "table_name" already exists
   ERROR: multiple primary keys for table "table_name" are not allowed
   ERROR: relation "index_name" already exists
   ERROR: constraint "constraint_name" for relation "table_name" already exists
   ERROR: duplicate key value violates unique constraint "ar_internal_metadata_pkey"
   ```

   These errors are normal if the database has already been partially initialized.

### **Option 2: Create New Database**

```bash
# Only use if no dump is available
rails db:create
rails db:migrate
rails db:seed
```

## 🔧 **Detailed Guide**

### **Prerequisites**

- PostgreSQL is installed and running
- `createdb` and `psql` commands are available
- You have access to a database dump file

### **Prepare Dump File**

1. **Find Dump File**
   ```bash
   # Typical names:
   # - carambus_api_development_YYYYMMDD_HHMMSS.sql
   # - carambus_development_dump.sql
   # - carambus_api_development.sql
   ```

2. **Check Dump File**
   ```bash
   # Check file size
   ls -lh /path/to/your/dump.sql
   
   # Show first lines
   head -20 /path/to/your/dump.sql
   ```

### **Create Database**

```bash
# Create new database
createdb carambus_development

# Or with specific parameters
createdb -h localhost -U username carambus_development
```

### **Import Dump**

```bash
# Simple import
psql -d carambus_development -f /path/to/your/dump.sql

# With specific parameters
psql -h localhost -U username -d carambus_development -f /path/to/your/dump.sql

# With progress display
psql -d carambus_development -f /path/to/your/dump.sql -v ON_ERROR_STOP=0
```

### **Monitor Import**

```bash
# Show import logs
tail -f /var/log/postgresql/postgresql-*.log

# Test database connection
psql -d carambus_development -c "SELECT version();"
psql -d carambus_development -c "\dt"
```

## 🐳 **Docker Integration**

### **Automatic Import**

If you're using Docker, you can have the dump imported automatically:

```yaml
# docker-compose.yml
services:
  postgres:
    volumes:
      - ./database/carambus_development.sql:/docker-entrypoint-initdb.d/carambus_development.sql
```

### **Manual Import in Docker Container**

```bash
# Import dump into running container
docker exec -i container_name psql -U username -d database_name < dump.sql

# Example:
docker exec -i carambus_postgres_1 psql -U www_data -d carambus_development < dump.sql
```

## 🚨 **Troubleshooting**

### **Common Issues**

1. **Permission Errors**
   ```bash
   # Check PostgreSQL users
   sudo -u postgres psql -c "\du"
   
   # Create user if needed
   sudo -u postgres createuser --interactive username
   ```

2. **Database Already Exists**
   ```bash
   # Drop and recreate database
   dropdb carambus_development
   createdb carambus_development
   ```

3. **Import Fails**
   ```bash
   # Check dump file for syntax errors
   psql -d carambus_development -f dump.sql 2>&1 | grep -i error
   
   # Repair dump file (if needed)
   sed -i 's/CREATE SCHEMA IF NOT EXISTS "public";//' dump.sql
   ```

### **Verification**

After import, you should see the following tables:

```bash
psql -d carambus_development -c "\dt" | grep -E "(users|clubs|tournaments|leagues)"
```

## 📚 **Additional Resources**

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Rails Database Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [Carambus Developer Guide](DEVELOPER_GUIDE.md)

---

**Tip**: Always use a database dump for development, as it contains all current data and the correct schema.
