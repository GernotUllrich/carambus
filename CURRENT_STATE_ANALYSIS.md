=== AKTUELLE SITUATION DOKUMENTATION ===
Datum: Do  4 Sep 2025 15:31:12 CEST

## 1. AKTUELLE MODE-KONFIGURATION

🔍 CURRENT MODE STATUS
============================================================
Current Configuration:
  API URL: https://newapi.carambus.de/
  Context: NBV
  Database: carambus_location_2459_production
  Deploy Basename: carambus
  Log File: linked file
  Puma Script: manage-puma-api.sh
Current Mode: LOCAL

📡 CONFIGURATION SOURCE:
----------------------------------------
Reading from local deployment configuration files
Local path: config/carambus.yml, config/database.yml

============================================================
DETAILED PARAMETER BREAKDOWN
============================================================

📋 PARAMETER DETAILS:
----------------------------------------
1.  season_name:     2025/2026
2.  application_name: carambus
3.  context:         NBV
4.  api_url:         https://newapi.carambus.de/
5.  basename:        carambus
6.  database:        carambus_location_2459_production
7.  domain:          carambus.de
8.  location_id:     2459
9.  club_id:         2459
10. rails_env:       development
11. host:            newapi.carambus.de
12. port:            8910
13. branch:          master
14. puma_script:     manage-puma-api.sh

🔄 COMPLETE PARAMETER STRING:
----------------------------------------
✅ All parameters configured
2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_location_2459_production,carambus.de,2459,2459,development,newapi.carambus.de,8910,master,manage-puma-api.sh

📝 USAGE:
----------------------------------------
To switch to this exact configuration:
bundle exec rails "mode:local[2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_location_2459_production,carambus.de,2459,2459,development,newapi.carambus.de,8910,master,manage-puma-api.sh]"

Or save this configuration:
./bin/mode-params.sh save my_current_config "2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_location_2459_production,carambus.de,2459,2459,development,newapi.carambus.de,8910,master,manage-puma-api.sh"

## 2. AKTUELLE KONFIGURATIONSDATEIEN
### config/carambus.yml:
---
default:
  carambus_api_url: https://newapi.carambus.de/
  location_id: 2459
  application_name: carambus
  basename: carambus
  support_email: gernot.ullrich@gmx.de
  business_name: PHAT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
  season_name: 2025/2026
  force_update: 'true'
  no_local_protection: 'false'
  club_id: 2459
development:
  carambus_api_url: https://newapi.carambus.de/
  location_id: 2459
  application_name: carambus
  basename: carambus
  support_email: gernot.ullrich@gmx.de
  business_name: PHAT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  context: NBV
  season_name: 2025/2026
  force_update: 'true'
  no_local_protection: 'false'
  club_id: 2459
production:
  carambus_api_url: https://newapi.carambus.de/
  location_id: 2459
  application_name: carambus
  basename: carambus
  support_email: gernot.ullrich@gmx.de
  business_name: PHAT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
  context: NBV
  season_name: 2025/2026
  force_update: 'true'
  no_local_protection: 'false'
  club_id: 2459

### config/database.yml:
---
default:
  adapter: postgresql
  encoding: unicode
  pool: 5
development:
  adapter: postgresql
  encoding: unicode
  pool: 5
  database: carambus_location_2459_development
  host: localhost
test:
  adapter: postgresql
  encoding: unicode
  pool: 5
  database: carambus_location_2459_test
  host: localhost
production:
  adapter: postgresql
  encoding: unicode
  pool: 5
  database: carambus_location_2459_production
  username:
  password:
  host: localhost

## 3. GESPEICHERTE MODE-KONFIGURATIONEN
📋 Saved configurations:
  api_hetzner: {:basename=>"carambus_api", :database=>"carambus_api_production", :domain=>"api.carambus.de", :rails_env=>"production", :host=>"newapi.carambus.de", :port=>"3001", :branch=>"master", :puma_script=>"manage-puma-api.sh"}
