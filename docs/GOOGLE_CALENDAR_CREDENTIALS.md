# Google Calendar Credentials Setup

## Overview

The automatic table reservation system uses Google Calendar API with Service Account credentials.
Credentials are location-specific and stored in Rails encrypted credentials.

## Credentials Structure

Edit credentials with:
```bash
EDITOR=vim rails credentials:edit
```

Add the following structure:

```yaml
google_service:
  project_id: "your-project-id"              # e.g., "carambus-test" or "bc-wedel"
  private_key_id: "abc123..."                # From JSON key file
  private_key: "-----BEGIN PRIVATE KEY-----\n..." # From JSON key file
  client_email: "name@project.iam.gserviceaccount.com"
  client_id: "1234567890..."                 # From JSON key file

location_calendar_id: "calendar-id@group.calendar.google.com"
```

## Location-Specific Examples

### BC Wedel (Location ID: 1)
```yaml
google_service:
  project_id: "bc-wedel"
  client_email: "bc-wedel@bc-wedel.iam.gserviceaccount.com"
  client_id: "117790394526710523367"
  private_key_id: "..." # From downloaded JSON key
  private_key: "..." # From downloaded JSON key

location_calendar_id: "bc-wedel-calendar@group.calendar.google.com"
```

### Carambus Test (Default/Fallback)
```yaml
google_service:
  project_id: "carambus-test"
  client_email: "service-test@carambus-test.iam.gserviceaccount.com"
  client_id: "110923757328591064447"
  private_key_id: "..." # From downloaded JSON key
  private_key: "..." # From downloaded JSON key

location_calendar_id: "test-calendar@group.calendar.google.com"
```

## Getting the Service Account JSON Key

1. **Google Cloud Console**: https://console.cloud.google.com/iam-admin/serviceaccounts
2. Select your project (e.g., "bc-wedel")
3. Click on the service account
4. Go to **"KEYS"** tab
5. Click **"ADD KEY"** → **"Create new key"**
6. Select **"JSON"** format
7. Click **"CREATE"** → File downloads to `~/Downloads/`

## JSON Key File Structure

The downloaded file looks like this:
```json
{
  "type": "service_account",
  "project_id": "bc-wedel",
  "private_key_id": "abc123def456...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...\n-----END PRIVATE KEY-----\n",
  "client_email": "bc-wedel@bc-wedel.iam.gserviceaccount.com",
  "client_id": "117790394526710523367",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/...",
  "universe_domain": "googleapis.com"
}
```

## Extracting Values for Rails Credentials

From the JSON file, copy these values:

1. **project_id**: Copy directly
2. **private_key_id**: Copy directly
3. **private_key**: Copy the entire string INCLUDING `\n` characters
4. **client_email**: Copy directly
5. **client_id**: Copy directly (it's a string, not a number!)

## Google Calendar Permissions

After creating the service account, grant calendar access:

1. Open **Google Calendar** in browser
2. Go to **Settings** → Select the calendar
3. **"Share with specific people"**
4. Add the **client_email** (e.g., `bc-wedel@bc-wedel.iam.gserviceaccount.com`)
5. Set permission to **"Make changes to events"**

## Testing the Configuration

```ruby
# In Rails console
service = GoogleCalendarService.calendar_service
calendar_id = GoogleCalendarService.calendar_id

# Try to list events
events = service.list_events(calendar_id, max_results: 10)
puts "Found #{events.items.count} events"
```

## Troubleshooting

### Error: "requiredAccessLevel: You need to have writer access"
→ Service account email not added to calendar sharing, or has wrong permissions

### Error: "Missing Google Service credential"
→ Rails credentials not configured correctly. Check `rails credentials:edit`

### Error: "Invalid private_key"
→ Make sure `\n` characters in private_key are preserved (use quotes in YAML)

## Code Usage

The `GoogleCalendarService` class centralizes all credential handling:

```ruby
# Get configured service
service = GoogleCalendarService.calendar_service

# Get calendar ID
calendar_id = GoogleCalendarService.calendar_id

# Create event
event = Google::Apis::CalendarV3::Event.new(...)
service.insert_event(calendar_id, event)
```

## Security Notes

- ⚠️ **NEVER** commit the JSON key file to git
- ⚠️ **NEVER** commit unencrypted credentials
- ✅ Use Rails encrypted credentials (`config/credentials.yml.enc`)
- ✅ Keep `config/master.key` secret and backed up securely
- ✅ Rotate service account keys periodically
