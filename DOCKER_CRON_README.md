# Docker Cron Jobs Setup for Carambus

## Overview

The Docker setup includes a dedicated cron service that runs scheduled rake tasks for the Carambus application. This replaces the traditional system cron jobs with containerized scheduled tasks.

## Services

### Cron Service
- **Container**: `carambus-cron-1`
- **Image**: Built from the same Dockerfile as the web service
- **User**: Runs as `root` to avoid permission issues
- **Command**: Uses a custom startup script (`cron-startup.sh`)

## Scheduled Tasks

The following rake tasks are scheduled to run automatically:

### Daily Tasks
- **2:00 AM**: `scrape:daily_update` - Daily data synchronization

### Weekly Tasks
- **Sunday 3:00 AM**: `cleanup:cleanup_paper_trail_versions` - Clean up unnecessary version records
- **Monday 4:00 AM**: `scrape:scrape_tournaments_optimized` - Scrape tournament data
- **Tuesday 4:00 AM**: `scrape:scrape_clubs_optimized` - Scrape club data  
- **Wednesday 4:00 AM**: `scrape:scrape_leagues_optimized` - Scrape league data

### Monthly Tasks
- **1st of month 5:00 AM**: `mode:backup` - Create configuration backup

## Files

### Configuration Files
- `docker-compose.yml` - Defines the cron service
- `crontab` - Contains the scheduled job definitions
- `cron-startup.sh` - Startup script that copies credentials and loads crontab

### Logs
- All cron job output is logged to `/app/log/cron.log` inside the container
- Container logs are available via `docker-compose logs cron`

## Setup Process

1. **Credentials**: The startup script automatically copies Rails credentials from the mounted volume
2. **Crontab Loading**: The crontab file is automatically loaded on container startup
3. **Cron Daemon**: Cron runs in foreground mode to keep the container alive

## Manual Testing

To test rake tasks manually:

```bash
# Test backup task
docker-compose exec cron bundle exec rake mode:backup

# Test cleanup task  
docker-compose exec cron bundle exec rake cleanup:cleanup_paper_trail_versions

# Check crontab
docker-compose exec cron crontab -l
```

## Monitoring

### Check Service Status
```bash
docker-compose ps cron
```

### View Logs
```bash
# Container logs
docker-compose logs cron

# Cron job logs
docker-compose exec cron tail -f /app/log/cron.log
```

### Check Crontab
```bash
docker-compose exec cron crontab -l
```

## Troubleshooting

### Credentials Issues
If rake tasks fail with credential errors:
1. Check if credentials are copied: `docker-compose exec cron ls -la /app/config/credentials/`
2. Manually copy credentials: `docker cp carambus_web:/app/config/credentials/production.* ./ && docker cp ./production.* carambus-cron-1:/app/config/credentials/`

### Permission Issues
The cron service runs as root to avoid permission issues with mounted volumes.

### Container Restart
To restart the cron service:
```bash
docker-compose restart cron
```

## Advantages over System Cron

1. **Isolation**: Cron jobs run in a dedicated container
2. **Consistency**: Same environment as the web application
3. **Portability**: Easy to deploy to different environments
4. **Logging**: Centralized logging with Docker
5. **Dependencies**: Automatic dependency management with Docker Compose 