# 🚀 **Quick Start for Developers**

Welcome to Carambus! This guide helps you get started with development quickly.

## 📋 **Prerequisites**

- **Ruby 3.2+** (recommended: 3.2.1)
- **Rails 7.2+**
- **PostgreSQL 15+**
- **Redis**
- **Git**
- **Docker** (optional, but recommended)
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

## 🐳 **Option 1: Docker Setup (Recommended)**

```bash
# Open terminal and run:
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Start Docker setup (everything runs automatically)
docker-compose -f docker-compose.development.api-server.yml up
```

**Advantages:**
- ✅ All dependencies are automatically installed
- ✅ Database is automatically configured
- ✅ No conflicts with local services
- ✅ Easy to start/stop

## 🖥️ **Option 2: Local Setup**

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

### **Step 1: Create local folders**
```bash
# Create local folders in carambus directory
mkdir -p docker-development-api/config/credentials
mkdir -p docker-development-api/database
```

### **Step 2: Copy credentials**
```bash
# Copy these files to docker-development-api/config/credentials/:
# - development.key
# - credentials.yml.enc

# Example (from another system):
cp /path/to/working/system/config/credentials/development.key docker-development-api/config/credentials/
cp /path/to/working/system/config/credentials/credentials.yml.enc docker-development-api/config/credentials/
```

### **Step 3: Copy database dump**
```bash
# Copy database dump to docker-development-api/database/:
cp /path/to/carambus_api_development_dump.sql.gz docker-development-api/database/
```

**Where to get them?**
- From another developer on the team
- From your local `carambus_api` folder
- From the team lead

## 🗄️ **Setup Database**

### **Option 1: Automatically via Docker (Recommended)**
```bash
# 1. Start Docker - this automatically imports all dumps!
docker-compose -f docker-compose.development.api-server.yml up --build

# PostgreSQL automatically imports all .sql/.sql.gz files from:
# ./docker-development-api/database/
```

### **Option 2: Manually via psql (only if PostgreSQL is running)**
```bash
# Only if the PostgreSQL container is running:
docker ps | grep postgres

# If container is running, then:
gunzip -c docker-development-api/database/carambus_api_development_dump.sql.gz | docker exec -i carambus-postgres-1 psql -U www_data -d carambus_api_development

# If container is not running, start Docker first (Option 1)
```

### **Option 3: Start with empty database**
```bash
# If no dump is available:
rails db:create
rails db:migrate
```

## 🚨 **Common Problems & Solutions**

### **GitHub access not working**
```bash
# Check SSH key
ssh-add -l

# If empty, add key:
ssh-add ~/.ssh/id_rsa

# Test SSH connection
ssh -T git@github.com
```

### **Docker not running**
```bash
# macOS (MacBook):
open -a Docker
# Wait until "Docker Desktop is running" appears in menu bar

# Linux (Server):
sudo systemctl start docker
sudo systemctl status docker

# Windows:
# Start Docker Desktop from Start menu

# Then wait until Docker is running, then:
docker-compose up
```

### **Docker container won't start**
```bash
# Stop and restart containers
docker-compose down
docker-compose up --build

# If user permission issues:
# Docker container runs as root, not as www-data
# This is normal for development environment

# Check logs
docker-compose logs web
```

### **Ports are occupied**
```bash
# Check ports
lsof -i :3000
lsof -i :5432
lsof -i :6379

# If occupied, use other ports or stop services
```

### **Credentials errors**
```bash
# Copy development key
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
gunzip -c docker-development-api/database/dump.sql.gz | psql -h localhost -p 5433 -U www_data -d carambus_api_development
```

**Note on Dump Import Errors**: When importing a database dump, some errors may occur that can be ignored:
- `relation "table_name" already exists` - Table already exists
- `multiple primary keys for table "table_name" are not allowed` - Primary key already defined
- `relation "index_name" already exists` - Index already exists
- `constraint "constraint_name" for relation "table_name" already exists` - Constraint already defined
- `duplicate key value violates unique constraint` - Metadata already set

These errors are normal if the database has already been partially initialized.

## 🔍 **First Steps After Setup**

1. **Start server**: `rails server` or Docker
2. **Open browser**: http://localhost:3000
3. **Admin interface**: http://localhost:3000/admin
4. **Test API**: http://localhost:3000/api

## 📚 **Next Steps**

- Read [Developer Guide](DEVELOPER_GUIDE.md)
- Study [API Documentation](API.md)
- Understand [Database Design](database_design.md)
- Talk to the team about current tasks

## 🆘 **Need Help?**

- **Team Lead**: Gernot Ullrich
- **Documentation**: This repository
- **Issues**: Use GitHub Issues
- **Chat**: Team chat (Slack/Discord)

---

**Good luck getting started! 🎯** 