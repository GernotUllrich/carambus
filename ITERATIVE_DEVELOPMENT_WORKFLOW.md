# Iterative Development Workflow

This document describes the streamlined workflow for iterative development and testing of minor changes without regenerating entire scenarios.

## Overview

The scenario system provides two deployment modes:

1. **Full Scenario Deployment** (`rake scenario:deploy[scenario_name]`) - For new scenarios or major configuration changes
2. **Quick Deployment** (`rake scenario:quick_deploy[scenario_name]`) - For iterative code development

## Quick Deployment Workflow

### Prerequisites

1. **Scenario must be deployed at least once** using the full deployment process
2. **Scenario configuration** (`config.yml`) should not be changed
3. **Changes should be committed and pushed** to git (recommended)

### Usage

```bash
rake scenario:quick_deploy[carambus_location_5101]
```

### What Quick Deploy Does

1. **Validates Prerequisites**
   - Checks if scenario configuration exists
   - Verifies Rails root directory exists
   - Shows deployment details (target server, basename, etc.)

2. **Git Operations**
   - Checks git status for uncommitted changes
   - Warns about uncommitted changes (with option to continue)
   - Pulls latest changes from git repository

3. **Asset Compilation**
   - Builds JavaScript and CSS assets using `yarn install && yarn build`
   - Only runs if `package.json` exists

4. **Capistrano Deployment**
   - Executes standard Capistrano deployment process
   - Deploys code changes to production server
   - Runs asset precompilation on server

5. **Service Management**
   - Restarts Puma service to pick up code changes
   - Reloads Nginx configuration (non-critical)

6. **Verification**
   - Tests application response (HTTP 200/302)
   - Provides deployment summary and next steps

### Example Output

```
🚀 QUICK DEPLOY: Deploying code changes for carambus_location_5101
============================================================
This will deploy code changes without regenerating scenario configurations.

📋 Deployment Details:
   Target: 192.168.178.107:82
   SSH: 192.168.178.107:8910
   Basename: carambus_location_5101

✅ Rails root found: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_5101

📋 Step 1: Checking git status...
   ✅ Working directory is clean

📥 Step 2: Pulling latest changes from git...
   ✅ Git pull completed successfully

🔨 Step 3: Building frontend assets...
   📦 Building JavaScript and CSS assets...
   ✅ Frontend assets built successfully

🎯 Step 4: Executing Capistrano deployment...
   Running: cap production deploy
   Target server: 192.168.178.107:8910
   ✅ Capistrano deployment completed successfully

🔄 Step 5: Restarting services...
   ✅ Puma service restarted successfully
   ✅ Nginx service reloaded successfully

🔍 Step 6: Verifying deployment...
   ✅ Application is responding correctly (HTTP 200)

🎉 QUICK DEPLOY COMPLETED SUCCESSFULLY!
============================================================
📱 Application URL: http://192.168.178.107:82/
🔧 Puma service: puma-carambus_location_5101.service
📋 Next steps:
   • Test your changes in the browser
   • Check application logs if needed: ssh -p 8910 www-data@192.168.178.107 'tail -f /var/www/carambus_location_5101/shared/log/production.log'
   • For major changes, consider running full deployment: rake scenario:deploy[carambus_location_5101]
```

## Development Workflow

### Typical Iterative Development Cycle

1. **Make Code Changes**
   ```bash
   # Edit your code in carambus_master
   vim app/controllers/locations_controller.rb
   vim app/javascript/controllers/table_monitor_controller.js
   ```

2. **Commit and Push Changes**
   ```bash
   git add .
   git commit -m "Fix table monitor optimistic updates"
   git push origin master
   ```

3. **Quick Deploy**
   ```bash
   rake scenario:quick_deploy[carambus_location_5101]
   ```

4. **Test Changes**
   - Open browser to `http://192.168.178.107:82/`
   - Test your changes
   - Check logs if needed

### When to Use Full Deployment vs Quick Deploy

#### Use Quick Deploy For:
- ✅ Controller changes
- ✅ View modifications
- ✅ JavaScript/CSS updates
- ✅ Model changes
- ✅ Route modifications
- ✅ Asset pipeline changes
- ✅ Gem updates (that don't affect configuration)

#### Use Full Deployment For:
- 🔄 Changes to `config.yml` scenario configuration
- 🔄 New environment variables
- 🔄 Database schema changes
- 🔄 New gems requiring server configuration
- 🔄 Nginx or Puma configuration changes
- 🔄 SSL certificate updates
- 🔄 New scenarios or major infrastructure changes

## Troubleshooting

### Common Issues

1. **"Rails root not found"**
   ```bash
   # Solution: Run full deployment first
   rake scenario:deploy[carambus_location_5101]
   ```

2. **"Git pull failed"**
   ```bash
   # Solution: Check git status and resolve conflicts
   cd /path/to/scenario/rails/root
   git status
   git pull origin master
   ```

3. **"Frontend asset build failed"**
   ```bash
   # Solution: Check Node.js and yarn setup
   cd /path/to/scenario/rails/root
   node --version
   yarn --version
   yarn install
   ```

4. **"Capistrano deployment failed"**
   ```bash
   # Solution: Check server connectivity and permissions
   ssh -p 8910 www-data@192.168.178.107
   # Check if scenario was deployed properly
   ```

5. **"Application not responding"**
   ```bash
   # Check service status
   ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status puma-carambus_location_5101'
   
   # Check application logs
   ssh -p 8910 www-data@192.168.178.107 'tail -f /var/www/carambus_location_5101/shared/log/production.log'
   ```

### Log Locations

- **Application logs**: `/var/www/{basename}/shared/log/production.log`
- **Puma logs**: `/var/www/{basename}/shared/log/puma-production.log`
- **Nginx logs**: `/var/log/nginx/error.log`, `/var/log/nginx/access.log`

### Useful Commands

```bash
# Check service status
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status puma-carambus_location_5101'

# Restart services manually
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart puma-carambus_location_5101'

# Check application response
curl -I http://192.168.178.107:82/

# Monitor logs in real-time
ssh -p 8910 www-data@192.168.178.107 'tail -f /var/www/carambus_location_5101/shared/log/production.log'
```

## Performance Considerations

- **Quick Deploy** typically takes 30-60 seconds (vs 5-10 minutes for full deployment)
- **Asset compilation** happens both locally and on server for reliability
- **Service restarts** are minimal (only Puma, Nginx reload)
- **Database operations** are skipped (no schema changes or dumps)

## Best Practices

1. **Commit Early and Often**: Always commit your changes before deploying
2. **Test Locally First**: Ensure your changes work in development
3. **Use Feature Branches**: For experimental changes, use git branches
4. **Monitor Logs**: Check application logs after deployment
5. **Verify Changes**: Always test your changes in the browser after deployment
6. **Keep Scenarios Updated**: Run full deployment periodically to ensure configuration consistency

## Integration with CI/CD

The quick deploy task can be integrated into CI/CD pipelines for automated deployments:

```bash
# In your CI/CD script
rake scenario:quick_deploy[carambus_location_5101]
```

This allows for:
- Automated testing deployments
- Staging environment updates
- Production hotfixes
- Feature branch deployments
