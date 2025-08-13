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

```bash
# Import database dump (if available)
gunzip -c carambus_api_development_dump.sql.gz | rails db:execute

# Or start with empty database
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

# Or import dump
gunzip -c dump.sql.gz | rails db:execute
```

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