# 🚀 **Quick Start for Developers**

Welcome to Carambus! This guide helps you get started with development quickly.

## 📋 **Prerequisites**

- **Ruby 3.2+** (recommended: 3.2.1)
- **Rails 7.2+**
- **PostgreSQL 15+**
- **Redis**
- **Git**
- **SSH Key** for GitHub access

## 🔑 **Setup GitHub Access (Important!)**

**The repository uses SSH authentication, not HTTPS!**

### **Step 1: Generate SSH Key**
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Add SSH key to ssh-agent
ssh-add ~/.ssh/id_rsa

# Display public key
cat ~/.ssh/id_rsa.pub
```

### **Step 2: Add SSH Key to GitHub**
1. Copy the public key (output from `cat ~/.ssh/id_rsa.pub`)
2. GitHub → Settings → SSH and GPG keys → "New SSH key"
3. Paste the key and save

### **Step 3: Test SSH Connection**
```bash
# Test SSH connection
ssh -T git@github.com

# Should output: "Hi username! You've successfully authenticated..."
```

## 🖥️ **Local Setup**

```bash
# Clone repository (IMPORTANT: Use SSH URL!)
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Install dependencies
bundle install
yarn install

# Setup database
# Option 1: Import existing database dump (recommended)
# Ensure you have a database dump file (e.g., carambus_api_development_YYYYMMDD_HHMMSS.sql)
# Create database and import dump:
createdb carambus_development
psql -d carambus_development -f /path/to/your/dump.sql

# Option 2: Create fresh database (if no dump available)
rails db:create
rails db:migrate
rails db:seed

# Start server
rails server
```

## 🔑 **Setup Credentials**

**Important:** You need the `development.key` and `credentials.yml.enc` from a working system.

### **Step 1: Copy credentials**
```bash
# Copy these files to config/credentials/:
# - development.key
# - credentials.yml.enc

# Example (from another system):
cp /path/to/working/system/config/credentials/development.key config/credentials/
cp /path/to/working/system/config/credentials/credentials.yml.enc config/credentials/
```

### **Step 2: Import database dump**
```bash
# Import database dump:
psql -d carambus_development -f /path/to/carambus_api_development_dump.sql
```

**Where to get them?**
- From another developer on the team
- From your local `carambus_api` directory
- From the team lead

## 🗄️ **Setup Database**

### **Option 1: Automatically via Enhanced Mode System (Recommended)**
```bash
# 1. Configure Enhanced Mode - this automatically imports all dumps!
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_development

# 2. Start server
rails server
```

### **Option 2: Manually via psql**
```bash
# Manually import database dump
gunzip -c /path/to/carambus_api_development_dump.sql.gz | psql -d carambus_development
```

### **Option 3: Start with empty database**
```bash
# If no dump available:
rails db:create
rails db:migrate
```

## 🚨 **Common Problems & Solutions**

### **GitHub access doesn't work**
```bash
# Check SSH key
ssh-add -l

# If empty, add key:
ssh-add ~/.ssh/id_rsa

# Test SSH connection
ssh -T git@github.com
```

### **PostgreSQL not running**
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl status postgresql

# Or on macOS:
brew services start postgresql
```

### **Redis not running**
```bash
# Start Redis
sudo systemctl start redis
sudo systemctl status redis

# Or on macOS:
brew services start redis
```

### **Ports are occupied**
```bash
# Check ports
lsof -i :3000
lsof -i :5432
lsof -i :6379

# If occupied, use different ports or stop services
```

### **Credentials errors**
```bash
# Copy development keys
cp /path/to/working/system/config/credentials/development.key config/credentials/
cp /path/to/working/system/config/credentials/credentials.yml.enc config/credentials/
```

### **Database errors**
```bash
# Recreate database
rails db:drop
rails db:create
rails db:migrate

# Or import dump (via psql)
gunzip -c /path/to/dump.sql.gz | psql -h localhost -U www_data -d carambus_api_development
```

**Note on dump import errors**: When importing a database dump, some errors may occur that can be ignored:
- `relation "table_name" already exists` - Table already exists
- `multiple primary keys for table "table_name" are not allowed` - Primary key already defined
- `relation "index_name" already exists` - Index already exists
- `constraint "constraint_name" for relation "table_name" already exists` - Constraint already defined
- `duplicate key value violates unique constraint` - Metadata already set

These errors are normal if the database was already partially initialized.

## 🔍 **First Steps After Setup**

1. **Start server**: `rails server`
2. **Open browser**: http://localhost:3000
3. **Admin interface**: http://localhost:3000/admin
4. **Test API**: http://localhost:3000/api

## 📚 **Next Steps**

- Read [Developer Guide](DEVELOPER_GUIDE.md)
- Study [API Documentation](API.md)
- Understand [Database Design](database_design.md)
- [Enhanced Mode System](enhanced_mode_system.en.md) for deployment configuration
- Talk to the team about current tasks

## 🆘 **Need Help?**

- **Team Lead**: Gernot Ullrich
- **Documentation**: This repository
- **Issues**: Use GitHub Issues
- **Chat**: Team chat (Slack/Discord)

---

**Good luck getting started! 🎯** 