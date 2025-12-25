# Config Lock Files

## Overview

The lock file mechanism allows you to protect configuration files on a production server from being overwritten, even when `bin/deploy_scenario.sh [scenario_name]` is executed.

## How It Works

If a `.lock` file exists next to a configuration file, that configuration file will NOT be overwritten during deployment.

### Example

On the production server:
```bash
# Protect configuration file from being overwritten
touch /var/www/carambus_location_2459/shared/config/carambus.yml.lock
```

During the next deployment, `carambus.yml` will be skipped:
```
📤 Uploading configuration files to server...
   💡 Tip: Create a .lock file on server to prevent overwriting (e.g., carambus.yml.lock)
   ✅ Uploaded database.yml
   🔒 Skipped carambus.yml (locked on server)
   ✅ Uploaded nginx.conf
   ...
```

## Supported Configuration Files

The lock mechanism works for all of the following files:

### Main Configuration
- `database.yml` → `database.yml.lock`
- `carambus.yml` → `carambus.yml.lock`
- `nginx.conf` → `nginx.conf.lock`
- `env.production` → `env.production.lock`

### Puma/Service Configuration
- `puma.service` → `puma.service.lock`
- `puma.rb` → `puma.rb.lock`
- `production.rb` → `production.rb.lock`

### Credentials
- `credentials/production.yml.enc` → `credentials/production.yml.enc.lock`
- `credentials/production.key` → `credentials/production.key.lock`

## Usage

### Creating a Lock File

On the production server as www-data:
```bash
# Lock a single file
touch /var/www/[basename]/shared/config/carambus.yml.lock

# Lock multiple files
cd /var/www/[basename]/shared/config
touch carambus.yml.lock database.yml.lock
```

### Removing a Lock File

```bash
# Remove lock
rm /var/www/[basename]/shared/config/carambus.yml.lock
```

### Checking Lock Status

```bash
# Show all locks
ls -la /var/www/[basename]/shared/config/*.lock
```

## Use Cases

### 1. Preserving Custom Production Configuration
You have manually customized `carambus.yml` on the production server (e.g., special settings for this server):
```bash
# Protect file from being overwritten
touch /var/www/carambus_location_2459/shared/config/carambus.yml.lock
```

### 2. Temporary Test Configuration
You're testing a new configuration and don't want it overwritten during the next deployment:
```bash
# Lock during testing phase
touch /var/www/carambus_bcw/shared/config/database.yml.lock

# After successful test: remove lock and deploy normally
rm /var/www/carambus_bcw/shared/config/database.yml.lock
```

### 3. Server-Specific Credentials
You're using different credentials on different servers:
```bash
# Copy credentials manually once and then lock
touch /var/www/carambus_location_2459/shared/config/credentials/production.key.lock
```

## Important Notes

⚠️ **Maintenance**: Lock files must be managed manually. The system does NOT remove them automatically.

⚠️ **Version Control**: Lock files are NOT checked into the Git repository. They only exist on the production server.

⚠️ **Backup**: Locked configuration files should be backed up separately, as they are no longer part of the standard deployment process.

💡 **Best Practice**: Document which files are locked on which servers and why.

## Technical Details

### Implementation

The check is performed in `lib/tasks/scenarios.rake`:

1. **Helper function `config_file_locked?`**: Checks if a `.lock` file exists
2. **Helper function `upload_config_file`**: Upload with lock check
3. **Upload process**: All config files are uploaded through `upload_config_file`

### SSH Commands

The lock check uses:
```ruby
ssh -p [port] www-data@[host] 'test -f [path].lock && echo locked || echo unlocked'
```

## Troubleshooting

### Lock Not Recognized

```bash
# Check if lock file exists and has correct permissions
ls -la /var/www/[basename]/shared/config/*.lock

# Lock file should be owned by www-data
sudo chown www-data:www-data /var/www/[basename]/shared/config/carambus.yml.lock
```

### File Overwritten Despite Lock

Check:
1. Is the lock file in the right location?
2. Does the lock file have exactly the right name? (must have `.lock` suffix)
3. Are SSH connection and permissions correct?

## See Also

- [Deployment Process](../developers/deployment-workflow.en.md)
- [Scenario Management](../developers/scenario-management.en.md)
- [Production Setup](PRODUCTION_SETUP.md)

