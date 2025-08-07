# Implementation Lessons - Carambus Docker Setup

## Overview

This document summarizes the key differences between the original plan and what actually worked during the fresh SD card test of the Carambus Docker setup.

## Key Differences from Original Plan

### ✅ What Actually Worked

#### 1. **GitHub SSH Setup (Required)**
- **Original Plan:** Use HTTPS with username/password
- **Actual Implementation:** SSH key authentication required
- **Reason:** GitHub no longer supports password authentication for Git operations
- **Solution:** Generate SSH key, add to GitHub, use SSH URLs

#### 2. **Database User Configuration**
- **Original Plan:** Use `carambus` user
- **Actual Implementation:** Use `www_data` user
- **Reason:** Production database uses `www_data` user
- **Solution:** Update docker-compose.yml and database dump

#### 3. **Database Dump User References**
- **Original Plan:** Use database dump as-is
- **Actual Implementation:** Fix user references in dump
- **Reason:** Dump contains `gullrich` user references
- **Solution:** Replace with `www_data` using sed

#### 4. **Asset Pipeline Configuration**
- **Original Plan:** Assets should work automatically
- **Actual Implementation:** Manual manifest.js configuration required
- **Reason:** Rails 7.2 asset pipeline needs explicit configuration
- **Solution:** Add `application.js` and `application.css` to manifest.js

#### 5. **CSS Import Configuration**
- **Original Plan:** CSS should compile automatically
- **Actual Implementation:** Manual application.css configuration required
- **Reason:** Tailwind CSS needs explicit import
- **Solution:** Add `@import "application.tailwind";` to application.css

#### 6. **JavaScript Build Process**
- **Original Plan:** Use `rails assets:precompile` only
- **Actual Implementation:** Use `yarn build` and `yarn build:css`
- **Reason:** esbuild and Tailwind need separate build steps
- **Solution:** Run `yarn build` for JS, `yarn build:css` for CSS, then `rails assets:precompile`

#### 7. **Asset Cache Management**
- **Original Plan:** Assets should update automatically
- **Actual Implementation:** Clear asset cache when rebuilding
- **Reason:** Rails caches compiled assets
- **Solution:** Use `rails assets:clobber` before `rails assets:precompile`

#### 8. **SSL Configuration**
- **Original Plan:** Use HTTPS with SSL certificates
- **Actual Implementation:** Temporarily disable SSL for testing
- **Reason:** SSL certificates not available for testing
- **Solution:** Comment out `config.force_ssl = true`

#### 9. **Docker Compose Syntax**
- **Original Plan:** Use `docker-compose` command
- **Actual Implementation:** Use `docker compose` command
- **Reason:** New Docker Compose plugin syntax
- **Solution:** Update all commands to use new syntax

### ❌ What Was Removed/Simplified

#### 1. **Cron Service**
- **Original Plan:** Include cron service for scheduled tasks
- **Actual Implementation:** Removed for simplicity
- **Reason:** Not essential for basic functionality
- **Future:** Can be added later if needed

#### 2. **Nginx SSL Configuration**
- **Original Plan:** Configure Nginx with SSL certificates
- **Actual Implementation:** Removed for testing
- **Reason:** SSL certificates not available
- **Future:** Can be configured for production

#### 3. **Complex Health Checks**
- **Original Plan:** Detailed health check configuration
- **Actual Implementation:** Simplified checks
- **Reason:** Basic functionality sufficient for testing
- **Future:** Can be enhanced for production

## Critical Issues Encountered

### 1. **GitHub Authentication**
```
git clone https://github.com/GernotUllrich/carambus.git
# Error: Password authentication is not supported for Git operations
```
**Solution:** Use SSH authentication

### 2. **Database User Mismatch**
```
ERROR: role "gullrich" does not exist
```
**Solution:** Fix database dump user references

### 3. **Asset Pipeline Missing Files**
```
ActionView::Template::Error (The asset "application.js" is not present in the asset pipeline.)
```
**Solution:** Configure manifest.js properly

### 4. **CSS Not Loading**
```
# CSS file contains @import instead of compiled Tailwind
```
**Solution:** Add `@import "application.tailwind";` to application.css and run `yarn build:css`

### 5. **JavaScript Not Loading**
```
# JavaScript file not generated
```
**Solution:** Run `yarn build` to compile JavaScript with esbuild

### 6. **SSL Redirect Issues**
```
HTTP/1.1 301 Moved Permanently
location: https://localhost:3000/login
```
**Solution:** Temporarily disable SSL

## Working Configuration

### Docker Compose Services
```yaml
services:
  postgres:
    environment:
      POSTGRES_USER: www_data
      POSTGRES_PASSWORD: toS6E7tARQafHCXz
      
  redis:
    # Standard Redis configuration
    
  web:
    environment:
      RAILS_ENV: production
      POSTGRES_USER: www_data
      POSTGRES_PASSWORD: toS6E7tARQafHCXz
```

### Asset Pipeline Configuration
```javascript
// app/assets/config/manifest.js
//= link_tree ../builds
//= link_tree ../images
//= link rails-ujs.js
//= link application.js
//= link application.css
```

### CSS Configuration
```css
/* app/assets/stylesheets/application.css */
@import "application.tailwind";
/* Scoreboard menu styles */
.scoreboard-menu {
  gap: 0.5rem !important;
}
/* ... rest of the file ... */
```

### Database Setup
```bash
# Fix database dump
gunzip -c carambus_production_20250805_224054.sql.gz | \
sed 's/OWNER TO gullrich/OWNER TO www_data/g' | \
gzip > carambus_production_fixed.sql.gz
```

### Build Process
```bash
# Build JavaScript and CSS
yarn build
yarn build:css

# Precompile assets
bundle exec rails assets:precompile
```

## Success Criteria (Updated)

### ✅ Core Functionality
- [ ] Docker and Docker Compose working
- [ ] PostgreSQL database with production data
- [ ] Rails application responding on port 3000
- [ ] Asset pipeline (CSS/JS) loading correctly
- [ ] External access working
- [ ] GitHub SSH access for updates

### ✅ Scoreboard Setup
- [ ] Desktop environment working
- [ ] Browser can access localhost:3000
- [ ] Scoreboard interface loads
- [ ] Fullscreen mode functional

## Lessons Learned

### 1. **Always Test Authentication First**
- GitHub SSH setup is critical
- Test SSH connection before proceeding
- Have fallback authentication methods

### 2. **Database User Consistency**
- Ensure database user matches across all configurations
- Fix database dumps to use correct user
- Test database connectivity early

### 3. **Asset Pipeline Requires Configuration**
- Rails 7.2 asset pipeline needs explicit manifest configuration
- Always check asset compilation during setup
- Verify CSS/JS loading in browser

### 4. **Build Process is Multi-Step**
- JavaScript needs `yarn build` with esbuild
- CSS needs `yarn build:css` for Tailwind
- Rails needs `assets:precompile` for final compilation
- Clear asset cache when rebuilding

### 5. **SSL Can Block Testing**
- Disable SSL temporarily for testing
- Configure SSL only when certificates are available
- Test HTTP access before enabling HTTPS

### 6. **Docker Compose Syntax Changes**
- Use `docker compose` instead of `docker-compose`
- Update all scripts and documentation
- Test commands before running

## Future Improvements

### 1. **Add Cron Service**
```yaml
cron:
  build: .
  user: root
  volumes:
    - ./crontab:/etc/cron.d/carambus:ro
    - ./cron-startup.sh:/usr/local/bin/cron-startup.sh:ro
  command: cron-startup.sh
```

### 2. **Configure SSL**
- Obtain SSL certificates
- Configure Nginx with SSL
- Enable HTTPS redirects

### 3. **Enhanced Monitoring**
- Add health checks
- Configure log rotation
- Set up monitoring alerts

## Conclusion

The actual implementation required significant deviations from the original plan, but resulted in a working Docker setup. The key was adapting to real-world constraints and focusing on core functionality first.

**Final Status:** ✅ **SUCCESS** - Carambus Docker setup working on Raspberry Pi with full asset pipeline support 