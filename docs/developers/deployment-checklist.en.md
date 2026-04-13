# Deployment Checklist for carambus_api Production

## Before Deployment (on Production Server)

### 1. Create Backup
```bash
# Create PostgreSQL dump
pg_dump carambus_api_production > backup_before_deployment_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Deploy Code (from Development)
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
git push  # already done
```

### 3. On Production Server: Pull Code
```bash
cd /path/to/carambus_api_production
git pull origin master
```

## Deployment Steps on Production

### 4. Bundle and Assets
```bash
bundle install
rake assets:precompile RAILS_ENV=production
```

### 5. Database Migrations
```bash
# Run migrations (STI + Videos table)
rake db:migrate RAILS_ENV=production
```

**Important Migrations:**
- `20260218185613_add_sti_fields_to_tournaments.rb` - STI for Tournaments
- `20260218193951_create_videos.rb` - Create Videos table

### 6. Create Placeholder Records
```bash
# CRITICAL: These must exist BEFORE scraping!
rake placeholders:create RAILS_ENV=production
```

**Creates:**
- Unknown Season
- Unknown Discipline
- Unknown Location
- Unknown Region
- Unknown Club

### 7. Optional: Migrate Existing Data
```bash
# If existing tournaments already use .first, migrate them:
rake placeholders:migrate_to_placeholders RAILS_ENV=production
```

### 8. Restart Server
```bash
# Depending on setup:
sudo systemctl restart puma-carambus_api
# or
touch tmp/restart.txt
```

## After Deployment: Run Scraping

### 9. Scrape YouTube Videos
```bash
# Scrape all YouTube sources fresh
rake youtube:scrape_all RAILS_ENV=production

# Or individually:
rake youtube:scrape[1] RAILS_ENV=production  # Kozoom
rake youtube:scrape[2] RAILS_ENV=production  # Carom Café
# etc.
```

### 10. Scrape UMB Tournaments
```bash
# Option A: Import all known IDs (recommended, faster)
rake umb:import_all RAILS_ENV=production

# Option B: Sequential scraping (slower, but complete)
rake umb:scrape_archive[1,500] RAILS_ENV=production
rake umb:scrape_all_details RAILS_ENV=production

# Option C: With UMB Scraper V2 (newer scraper with improved KO parsing)
rake umb_v2:scrape_range[300,400] RAILS_ENV=production
```

**Recommendation:** Use `umb:import_all` — it is the fastest and automatically skips non-existent IDs.

**Important:** The UMB Scraper now automatically creates:
- Locations from "Place: City (Country)"
- Seasons based on "Starts on" date
- Organizer "UMB" (Union Mondiale de Billard)

### 11. Check Status
```bash
# Placeholder statistics
rake placeholders:stats RAILS_ENV=production

# List incomplete records
rake placeholders:list_incomplete RAILS_ENV=production
```

### 12. Automatic Fixes (optional)
```bash
# Automatically fix disciplines based on tournament titles
rake placeholders:auto_fix_disciplines RAILS_ENV=production
```

## After Scraping: Admin Interface

### 13. Manually Process Incomplete Records
```
https://your-production-url/admin/incomplete_records
```

Here you can manually fix remaining tournaments with placeholder references:
- Select season
- Create/assign location
- Fix discipline
- Assign organizer

## Monitoring & Troubleshooting

### Monitor Logs
```bash
tail -f log/production.log
```

### Important Checks
```bash
# Video count
rails runner "puts 'Videos: ' + Video.count.to_s" RAILS_ENV=production

# Tournament count
rails runner "puts 'Tournaments: ' + InternationalTournament.count.to_s" RAILS_ENV=production

# Placeholder usage
rake placeholders:stats RAILS_ENV=production
```

### If Problems Occur
```bash
# Roll back last migration
rake db:rollback RAILS_ENV=production

# Restore database from backup
psql carambus_api_production < backup_before_deployment_TIMESTAMP.sql

# Check server logs
tail -n 100 log/production.log
```

## Summary of Order

1. ✅ Create backup
2. ✅ Deploy & pull code
3. ✅ Bundle & assets
4. ✅ **DB migrations** (`rake db:migrate`)
5. ✅ **Create placeholder records** (`rake placeholders:create`) - **CRITICAL!**
6. ✅ Restart server
7. ✅ **Scrape YouTube** (`rake youtube:scrape_all`)
8. ✅ **Scrape UMB** (`rake umb:import_all` or `rake umb:scrape_archive[1,500]` + `rake umb:scrape_all_details`)
9. ✅ Check status (`rake placeholders:stats`)
10. ✅ Use admin interface (`/admin/incomplete_records`)

## Important Notes

⚠️ **CRITICAL:** `rake placeholders:create` must run BEFORE scraping!

✅ The UMB Scraper now automatically creates:
- Locations (parsed from Place text)
- Seasons (calculated from start date)
- UMB as Organizer

✅ YouTube Scraper now sets `metadata_extracted = true` automatically

✅ Incomplete records can be corrected later in the admin interface

## New Features in Scraping

1. **Auto-Location-Creation**: "Nice (France)" → Location: Nice, Country: FR
2. **Auto-Season-Creation**: Tournament from 15.01.2009 → Season 2008/2009
3. **Auto-Organizer-Assignment**: UMB Region is assigned to all UMB tournaments
4. **Better Discipline Detection**: "3-cushion" in title → Three-cushion
5. **Graceful Degradation**: If something is missing → Unknown Placeholder instead of error
