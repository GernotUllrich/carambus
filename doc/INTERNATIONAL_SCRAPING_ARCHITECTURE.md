# International Video Scraping Architecture (SOOP Live & Kozoom)

This document summarizes the architecture, implementation details, and deployment configuration for scraping international carom billiards videos from SOOP Live and Kozoom. It is intended for developers and LLMs to quickly understand the current state of the system.

## 1. Automated Scraper Jobs (`carambus_api`)

The core scraping logic is orchestrated by `DailyInternationalScrapeJob` (`app/jobs/daily_international_scrape_job.rb`), which is executed daily via a cron job.
This job sequentially triggers scraping for YouTube, SOOP Live, and Kozoom, and then processes the newly fetched videos (auto-tagging, tournament assignment, translation).

### SOOP Live (formerly AfreecaTV)
- **Service:** `SoopliveScraper` (`app/services/sooplive_scraper.rb`)
- **API Endpoints Used:**
  - `https://chapi.sooplive.co.kr/api/{channel_id}/vods/all/streamer?page=1&per_page=60`
- **Data Extracted:** Video URL, Thumbnail, Title, Duration, External ID, Publish Date, Tags.
- **Channels:** Iterates over predefined official channels (e.g., `afbilliards1`, `afbilliards2`, etc.) defined in `InternationalSource::KNOWN_FIVESIX_CHANNELS`.
- **Filtering:** Uses `Video.contains_carom_keywords?` to ensure only relevant billiards content is saved.

### Kozoom TV
- **Service:** `KozoomScraper` (`app/services/kozoom_scraper.rb`)
- **Authentication:** Kozoom uses a modern JWT (JSON Web Token) approach.
  - The scraper authenticates via `POST https://api.kozoom.com/auth/login`.
  - Credentials (`email` and `password`) are securely stored in **Rails encrypted credentials** (`Rails.application.credentials.dig(:kozoom, :email)`). **NEVER store them in plain text or in the `settings` database table.**
  - The JWT must be passed in the `Authorization: Bearer <token>` header for subsequent requests.
  - *Note:* The API requires `OpenSSL::SSL::VERIFY_NONE` for the HTTP client due to certificate chain issues on the server.
- **API Endpoints Used:**
  - Events: `GET https://api.kozoom.com/events/days?startDate=...&endDate=...&sportId=1`
  - Videos: `GET https://api.kozoom.com/videos?eventId={event_id}&lang=en`
- **Frontend Link:** Videos are linked directly to their respective event page (`https://tv.kozoom.com/en/event/{event_id}`).

## 2. Capistrano & Whenever Cronjob Deployment

A major learning was how to properly configure Capistrano and the Whenever gem for a multi-repository setup (`carambus_api` and `carambus`).

- **The Problem:** The `schedule.rb` defines roles for tasks (e.g., `roles: [:app]`). However, if Capistrano's `whenever_roles` configuration does not include the server's role, the crontab will not be generated on the target server.
- **The Solution:**
  1. In `config/schedule.rb`, define the task with `roles: [:app]`.
  2. In the deployment configuration (e.g., `config/deploy.rb`), explicitly tell Capistrano to run Whenever for the app role:
     ```ruby
     set :whenever_roles, -> { %i[app] } # For API
     set :whenever_roles, -> { %i[app local] } # For Frontend (BCW)
     ```
  3. Ensure that `whenever_variables` are properly **single-quoted** in `deploy.rb` to prevent bash from misinterpreting `&` characters as background job instructions:
     ```ruby
     set :whenever_variables, lambda {
       "'environment=#{fetch(:rails_env, "production")}&path=#{fetch(:deploy_to)}/current&scenarioname=#{fetch(:basename)}&location_id=#{fetch(:location_id, "1")}'"
     }
     ```

## 3. Frontend Integration (`carambus_bcw`)

- **Premium Badges:** Since Kozoom videos require a paid subscription (Event Pass or Global Pass) to be viewed, they are visually distinguished in the frontend.
- **Implementation:** Any video where `video.player == 'kozoom'` receives a yellow `PREMIUM` badge (with a lock icon) overlaid on its thumbnail.
- This UI logic is distributed across:
  - `app/views/international/index.html.erb` (Main dashboard)
  - `app/views/international/videos/index.html.erb` (Video listing)
  - `app/views/international/tournaments/show.html.erb` (Tournament detail view)
