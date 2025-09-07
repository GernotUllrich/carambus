# Scenario Management System

The Scenario Management System allows managing and automatically deploying different deployment environments (scenarios) for Carambus.

## Overview

The system supports various scenarios such as:
- **carambus**: Main production environment
- **carambus_location_5101**: Local server instance for location 5101
- **carambus_location_2459**: Local server instance for location 2459
- **carambus_location_2460**: Local server instance for location 2460

## Core Concepts

### Scenario Configuration

Each scenario is defined by a `config.yml` file:

```yaml
scenario:
  name: carambus
  application_name: carambus
  basename: carambus

environments:
  development:
    database_name: carambus_development
    database_username: carambus_user
    webserver_host: localhost
    webserver_port: 3000
    ssh_host: localhost
    ssh_port: 22
    ssl_enabled: false
    
  production:
    database_name: carambus_production
    database_username: carambus_user
    webserver_host: new.carambus.de
    webserver_port: 80
    ssh_host: new.carambus.de
    ssh_port: 8910
    ssl_enabled: true
```

### Automatic Sequence Management

The system ensures that all database sequences are correctly set to > 50,000,000 to avoid conflicts with the `LocalProtector`.

## Available Tasks

### Scenario Creation

```bash
# Create new scenario
rake "scenario:create[scenario_name]"

# Create Rails root for scenario
rake "scenario:create_rails_root[scenario_name]"
```

### Development Setup

```bash
# Setup development environment
rake "scenario:setup[scenario_name,development]"

# With Rails root directory
rake "scenario:setup_with_rails_root[scenario_name,development]"
```

### Production Deployment

```bash
# Full production deployment
rake "scenario:deploy[scenario_name]"

# With conflict analysis
rake "scenario:deploy_with_conflict_analysis[scenario_name]"
```

### Database Management

```bash
# Create database dump
rake "scenario:create_database_dump[scenario_name,environment]"

# Restore database dump
rake "scenario:restore_database_dump[scenario_name,environment]"
```

## Deployment Process

### 1. Generate Configuration Files

The system automatically generates:
- `database.yml`
- `carambus.yml`
- `nginx.conf`
- `puma.service`
- `puma.rb`
- `deploy.rb`
- `production.rb`

### 2. Database Setup

- **Template Optimization**: Uses `createdb --template` for fast database creation
- **Automatic Transformations**: Sets scenario-specific settings
- **Sequence Reset**: Ensures all sequences are > 50,000,000

### 3. Capistrano Deployment

- **Git Deployment**: Automatic code deployment
- **Asset Precompilation**: CSS/JS build
- **Database Migration**: Automatic schema updates
- **Service Management**: Puma/Nginx configuration
- **SSL Setup**: Automatic Let's Encrypt integration

## Optimizations

### Database Template

**Before:**
```bash
pg_dump carambus_api_development | psql temp_db
```

**After:**
```bash
createdb temp_db --template=carambus_api_development
```

**Advantage:** Significantly faster for large databases.

### Integrated SSL Management

SSL certificates are automatically managed via Capistrano:
- Automatic Let's Encrypt integration
- Nginx configuration with SSL
- Automatic certificate renewal

### Automatic Sequence Management

The system automatically runs `Version.sequence_reset`:
- After every database restore
- During every production deployment
- Prevents `LocalProtector` conflicts

## Troubleshooting

### Common Issues

#### 1. Sequence Conflicts

**Problem:** `ActiveRecord::RecordNotDestroyed` errors
**Solution:** Run `Version.sequence_reset`

```bash
bundle exec rails runner 'Version.sequence_reset'
```

#### 2. Bundle Command Not Found

**Problem:** `bundle: command not found` on server
**Solution:** System automatically uses `$HOME/.rbenv/bin/rbenv exec bundle`

#### 3. SSL Certificate Issues

**Problem:** SSL setup fails
**Solution:** Check domain configuration and Nginx status

```bash
sudo certbot certificates
sudo nginx -t
```

## Best Practices

### Scenario Naming Convention

- **Main Production**: `carambus`
- **Local Servers**: `carambus_location_[ID]`
- **Development**: `carambus_development`

### Database Backup

Create regular backups:
```bash
rake "scenario:create_database_dump[carambus,production]"
```

### Deployment Testing

Test deployments in development environment:
```bash
rake "scenario:setup[carambus,development]"
```

## Integration with Existing Systems

The Scenario Management System replaces:
- ❌ Manual Docker configuration
- ❌ Manual mode switching
- ❌ Manual SSL setup
- ❌ Manual database management

**Advantages:**
- ✅ Automated deployments
- ✅ Consistent configuration
- ✅ Easy maintenance
- ✅ Scalable architecture
