# 🚀 Getting Started Guide for New Carambus Developers

## 👋 Welcome to the Team!

This guide helps you set up a working development environment in 2-3 hours and implement your first change.

## 🎯 What you will achieve:

1. ✅ **Development environment running** on your MacBook
2. ✅ **API Server starts** successfully
3. ✅ **First change** implemented and tested
4. ✅ **Understanding** of the Carambus architecture

## 📋 Prerequisites

### On your MacBook:
- **Ruby 3.2+** (will be installed automatically)
- **PostgreSQL** (will be installed automatically)
- **Git** (should already be installed)
- **Docker Desktop** (for the recommended setup)

### No prior knowledge needed:
- ❌ Docker (will be explained)
- ❌ Carambus-specific knowledge
- ❌ Billiards expertise

## 🚀 Quick Start (30 minutes)

### Option 1: Docker Setup (Recommended)
```bash
# Open terminal and run:
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

# Start Docker setup (everything runs automatically)
docker-compose -f docker-compose.development.api-server.yml up
```

### Option 2: Manual Setup (For Experts)
```bash
# Install dependencies
bundle install

# Create database (if not exists)
rails db:create

# Start server
rails server -p 3001
```

### Step 3: Test success
Open http://localhost:3001 in your browser. You should see the Carambus homepage!

## 🐳 Understanding Docker Setup

### What does the Docker setup do?
The `docker-compose.development.api-server.yml` automatically starts:

- **PostgreSQL** on port 5433 (avoids conflicts)
- **Redis** on port 6380 (avoids conflicts)
- **Rails** on port 3001 (avoids conflicts)
- **All dependencies** are automatically installed

### Understanding ports:
- **Web Server**: Port 3001 (http://localhost:3001)
- **PostgreSQL**: Port 5433 (local development)
- **Redis**: Port 6380 (local development)

### Environment variables:
The setup uses `env.development.api-server` with:
- `RAILS_ENV=development`
- `DEPLOYMENT_TYPE=API_SERVER`
- Custom ports for local development

## 🔑 Credentials and Local Development

### What you need from the Team Lead:
The team lead gives you a **local development folder** (outside the repository) with:

- **Credentials**: `development.key` and `credentials.yml.enc`
- **Database dump**: `carambus_api_development_dump.sql.gz`
- **Docker setup**: Customized compose files

### Where these files belong:
```bash
# Copy credentials
cp /path/to/local-dev-folder/config/credentials/* config/credentials/

# Copy database dump
mkdir -p doc/doc-local/docker/
cp /path/to/local-dev-folder/database/*.sql.gz doc/doc-local/docker/

# Copy Docker setup
cp /path/to/local-dev-folder/docker-compose.development.api-server.yml .
cp /path/to/local-dev-folder/env.development.api-server .
```

## 🏗️ What is Carambus? (15 minutes)

### Understand the architecture:
```
┌─────────────────┐    ┌─────────────────┐
│   Local Server  │    │   API Server    │
│  (Scoreboards)  │◄──►│  (Central API)  │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
```

### What you're developing:
- **API Server**: Central API for all Carambus clients
- **Scraper**: Collects data from external sources (BA/CC)
- **Database**: Manages tournaments, players, leagues

## 🔧 First Task: Understand the Scraper (30 minutes)

### What is a scraper?
A scraper is a program that automatically collects data from websites.

### Where to find the scraper:
```bash
# Find scraper code:
find . -name "*scraper*" -type f
```

### First change:
1. **Open scraper code** in your editor
2. **Make a small change** (e.g., add a comment)
3. **Test** if the server still runs
4. **Have a success experience**! 🎉

## 🆘 Common Problems and Solutions

### Docker problems:
```bash
# Docker not running
open -a Docker

# Ports are occupied
docker-compose down
docker-compose -f docker-compose.development.api-server.yml up
```

### Credentials problems:
```bash
# If Rails asks for secret_key_base
# Team lead gives you development.key and credentials.yml.enc
```

### Database problems:
```bash
# If database doesn't start
docker-compose logs postgres
```

## 📚 Next Steps

### Today:
- [ ] Development environment running
- [ ] First change implemented
- [ ] Understanding of architecture

### This week:
- [ ] Larger change to the scraper
- [ ] Write tests
- [ ] Create pull request

### Next week:
- [ ] Understand Docker environment
- [ ] Run local tests
- [ ] Give code reviews

## 🆘 Getting Help

### When you have problems:
1. **Ask immediately** - don't wait!
2. **Screenshots** of error messages
3. **Copy terminal output**

### Contacts:
- **Team chat**: [Slack/Discord Link]
- **Code review**: [GitHub Link]
- **Documentation**: [Link to this page]

## 🎯 Success Metrics

### After 2 hours:
- ✅ Server running on port 3001
- ✅ Browser shows Carambus page
- ✅ First change implemented

### After 1 week:
- ✅ Understanding of scraper architecture
- ✅ Independent implementation
- ✅ First pull request

### After 1 month:
- ✅ Full integration into team
- ✅ Give code reviews
- ✅ Develop new features

## 🔄 Give Feedback

### What works well?
- [ ] This guide
- [ ] Development environment
- [ ] Team support

### What can be improved?
- [ ] Documentation
- [ ] Setup process
- [ ] Architecture explanation

---

**🎉 Congratulations! You are now part of the Carambus development team!**

**💡 Tip**: Start with small changes and gradually increase. The team will help you! 