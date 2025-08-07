# Fresh SD Test Checklist - Carambus Docker

## Pre-Test Preparation

### Required Files (from working server bvbw)
- [ ] Database dump: `carambus_production_20250805_224054.sql.gz`
- [ ] Rails credentials: `production.key` and `production.yml.enc`
- [ ] REVISION file with current Git hash

### Hardware Setup
- [ ] Raspberry Pi 4 with 32GB+ SD card (for scoreboard setup)
- [ ] Network connection to 192.168.178.53
- [ ] SSH access enabled
- [ ] Monitor/display for scoreboard interface

## Step-by-Step Test Procedure

### Phase 1: System Setup
```bash
# 1. Flash fresh Raspberry Pi OS Desktop (64-bit) for scoreboard setup
# 2. Enable SSH during setup
# 3. Enable VNC if needed for remote desktop access
# 4. Connect via SSH
ssh pi@192.168.178.53

# 5. Update system
sudo apt update && sudo apt upgrade -y

# 6. Configure desktop for scoreboard use
# - Set up auto-login if needed
# - Configure display settings for scoreboard
# - Set up browser for scoreboard interface

# 7. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi

# 8. Logout and login again
exit
ssh pi@192.168.178.53

# 9. Install Docker Compose
sudo apt install docker-compose-plugin -y
```

### Phase 2: GitHub SSH Setup
```bash
# 1. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""

# 2. Start SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 3. Add GitHub to known hosts
ssh-keyscan github.com >> ~/.ssh/known_hosts

# 4. Display public key for GitHub
cat ~/.ssh/id_ed25519.pub
# Copy this key and add it to GitHub repository

# 5. Test GitHub connection
ssh -T git@github.com
```

### Phase 3: Application Setup
```bash
# 1. Clone repository using SSH
cd /home/pi
git clone git@github.com:GernotUllrich/carambus.git
cd carambus
git checkout master

# 2. Create directories
mkdir -p doc/doc-local/docker/shared/config/credentials
mkdir -p tmp/pids tmp/cache tmp/sockets
mkdir -p log storage

# 3. Copy production data (from local machine)
# Database dump
scp docker-production-data/carambus_production_20250805_224054.sql.gz pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/

# Rails credentials
scp doc/doc-local/docker/shared/config/credentials/production.* pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/shared/config/credentials/

# REVISION file
git rev-parse HEAD > REVISION
scp REVISION pi@192.168.178.53:/home/pi/carambus/

# 4. Set permissions
chmod -R 777 tmp log storage
chmod 600 doc/doc-local/docker/shared/config/credentials/production.key
```

### Phase 4: Database Setup Fixes
```bash
# 1. Fix database dump user references
gunzip -c doc/doc-local/docker/carambus_production_20250805_224054.sql.gz | \
sed 's/OWNER TO gullrich/OWNER TO www_data/g' | \
sed 's/OWNER TO \"gullrich\"/OWNER TO \"www_data\"/g' | \
gzip > doc/doc-local/docker/carambus_production_fixed.sql.gz

# 2. Update docker-compose.yml to use fixed database dump
sed -i 's/carambus_production_20250805_224054.sql.gz/carambus_production_fixed.sql.gz/g' docker-compose.yml

# 3. Update database user in docker-compose.yml
sed -i 's/POSTGRES_USER: carambus/POSTGRES_USER: www_data/g' docker-compose.yml
sed -i 's/POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-carambus_password}/POSTGRES_PASSWORD: toS6E7tARQafHCXz/g' docker-compose.yml

# 4. Remove obsolete version attribute
sed -i '/^version:/d' docker-compose.yml
```

### Phase 5: Build and Deploy
```bash
# 1. Build images
docker compose build --no-cache

# 2. Start services
docker compose up -d

# 3. Wait for startup
sleep 30

# 4. Check service status
docker compose ps
```

### Phase 6: Asset Pipeline Fixes
```bash
# 1. Fix manifest.js to include application assets
docker compose exec -u root web bash -c 'cat > /app/app/assets/config/manifest.js << EOF
//= link_tree ../builds
//= link_tree ../images
//= link rails-ujs.js
//= link application.js
//= link application.css
EOF'

# 2. Fix application.css to import Tailwind
docker compose exec -u root web bash -c 'cat > /app/app/assets/stylesheets/application.css << EOF
@import "application.tailwind";
/* Scoreboard menu styles */
.scoreboard-menu {
  gap: 0.5rem !important;
}
.scoreboard-menu-btn {
  background: transparent;
  border: none;
  padding: 0.2em 0.2em;
  border-radius: 0.5em;
  transition: background 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}
.scoreboard-menu-btn:active, .scoreboard-menu-btn-active {
  background: #2d3748;
  outline: 2px solid #e53e3e;
}
.scoreboard-menu-icon,
.scoreboard-menu-text {
  color: inherit;
}
.scoreboard-menu-text {
  font-size: 0.875rem;
  font-weight: 500;
}
.scoreboard-menu-btn:hover {
  background: rgba(255, 255, 255, 0.1);
}
.scoreboard-menu-btn:focus {
  outline: 2px solid #e53e3e;
  outline-offset: 2px;
}
EOF'

# 3. Temporarily disable SSL for testing
docker compose exec -u root web sed -i 's/config.force_ssl = true/# config.force_ssl = true/' /app/config/environments/production.rb

# 4. Build JavaScript and CSS assets
docker compose exec web yarn build
docker compose exec web yarn build:css

# 5. Precompile assets
docker compose exec web bundle exec rails assets:precompile

# 6. Restart web service
docker compose restart web
```

### Phase 7: Verification Tests
```bash
# 1. Test database
docker compose exec postgres psql -U www_data -d carambus_production -c "SELECT COUNT(*) FROM users;"

# 2. Test web application
curl -I http://localhost:3000/login

# 3. Test external access
curl -I http://192.168.178.53:3000/login

# 4. Test asset pipeline
curl -s http://localhost:3000/login | grep -E "(stylesheet|script)"

# 5. Run comprehensive test
./test-docker-setup.sh

# 6. Test scoreboard functionality
# - Open browser on Pi desktop
# - Navigate to http://localhost:3000
# - Test scoreboard interface
# - Verify fullscreen mode works
# - Test scoreboard menu navigation
```

## Success Criteria

### ✅ System Level
- [ ] Docker installed and running
- [ ] Docker Compose available (`docker compose` command works)
- [ ] All services (postgres, redis, web) show "Up" status
- [ ] No critical errors in docker compose logs

### ✅ GitHub Level
- [ ] SSH key generated and added to GitHub
- [ ] Repository cloned successfully using SSH
- [ ] Git operations work without password prompts

### ✅ Database Level
- [ ] PostgreSQL container running
- [ ] Database populated with production data
- [ ] Rails can connect to database with www_data user
- [ ] Database dump user references fixed

### ✅ Application Level
- [ ] Rails application responds on port 3000
- [ ] Login page loads without 500 errors
- [ ] CSS and JavaScript files load correctly
- [ ] Asset pipeline working (application.js and application.css generated)
- [ ] External access working (from other machines)

### ✅ Scoreboard Level
- [ ] Desktop environment working
- [ ] Browser can access localhost:3000
- [ ] Scoreboard interface loads correctly
- [ ] Fullscreen mode functional
- [ ] Scoreboard menu responsive

## Troubleshooting Guide

### If GitHub SSH Connection Fails
```bash
# Check SSH key
ls -la ~/.ssh/id_ed25519*

# Test connection
ssh -T git@github.com

# Add to known hosts if needed
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### If Database Connection Fails
```bash
# Check PostgreSQL logs
docker compose logs postgres

# Check if database user exists
docker compose exec postgres psql -U www_data -d carambus_production -c "\du"

# If user doesn't exist, recreate container
docker compose down -v
docker compose up -d postgres
```

### If Asset Pipeline Fails
```bash
# Check manifest.js
docker compose exec web cat /app/app/assets/config/manifest.js

# Check application.css
docker compose exec web cat /app/app/assets/stylesheets/application.css

# Build JavaScript and CSS
docker compose exec web yarn build
docker compose exec web yarn build:css

# Clear asset cache and rebuild
docker compose exec web bundle exec rails assets:clobber
docker compose exec web bundle exec rails assets:precompile

# Check asset files
docker compose exec web ls -la /app/public/assets/ | grep application
docker compose exec web ls -la /app/app/assets/builds/

# Verify CSS content
docker compose exec web head -10 /app/app/assets/builds/application.css
```

### If Web Application Fails
```bash
# Check Rails logs
docker compose logs web

# Enable detailed error pages temporarily
docker compose exec -u root web sed -i 's/config.consider_all_requests_local = false/config.consider_all_requests_local = true/' /app/config/environments/production.rb
```

### If Scoreboard Interface Fails
```bash
# Check if browser is installed
which chromium-browser || which firefox

# Test localhost access
curl -I http://localhost:3000

# Check display settings
xrandr --listmonitors

# Test fullscreen mode
# Open browser and press F11 or use browser's fullscreen mode
```

## Expected Results

After successful completion:
1. Web application accessible at http://192.168.178.53:3000
2. Database contains production data with www_data user
3. All assets (CSS/JS) loading correctly
4. No critical errors in logs
5. Scoreboard interface accessible via desktop browser
6. Fullscreen scoreboard mode functional
7. GitHub SSH access working for future updates

## Key Differences from Original Plan

### What Actually Worked:
1. **SSH Key Setup** - Required for GitHub access (no password auth)
2. **Database User Fix** - Changed from `carambus` to `www_data`
3. **Database Dump Fix** - Replaced `gullrich` user references with `www_data`
4. **Asset Pipeline Fix** - Added `application.js` and `application.css` to manifest.js
5. **CSS Import Fix** - Added `@import "application.tailwind";` to application.css
6. **JavaScript Build** - Used `yarn build` with esbuild for proper JS compilation
7. **CSS Build** - Used `yarn build:css` for Tailwind compilation
8. **SSL Disable** - Temporarily disabled for testing
9. **Docker Compose Syntax** - Used `docker compose` instead of `docker-compose`
10. **Asset Cache Clear** - Used `rails assets:clobber` to clear stale assets

### What Was Removed:
1. **Cron Service** - Not implemented in this test
2. **Nginx SSL** - Not configured for this test
3. **Complex Health Checks** - Simplified for basic functionality

## Rollback Plan

If test fails:
1. Stop all services: `docker compose down`
2. Remove volumes: `docker compose down -v`
3. Start fresh: Follow this checklist from Phase 1 