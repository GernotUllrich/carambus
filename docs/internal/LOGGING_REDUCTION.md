# Logging Reduction - March 2026

## Problem

Excessive logging in production causing:
- Log spam every 20 seconds due to auto-refresh polling
- Security risk: Session data with CSRF tokens and encrypted passwords being logged
- Multiple redundant debug statements on every request
- Log files growing too large too quickly

## Changes Made

### 1. Removed Security Risk - Session Data Logging

**File**: `app/controllers/locations_controller.rb`

- **Line 601**: Removed `Rails.logger.info "Session Data: #{session.to_hash}"`
- **Line 632**: Removed `Rails.logger.info "Session Data after auto sign_in: #{session.to_hash}"`

Session data contains sensitive information including:
- CSRF tokens
- Encrypted user keys  
- Authentication tokens

This data should NEVER be logged in production.

### 2. Changed Debug Statements from INFO to DEBUG Level

**File**: `app/controllers/locations_controller.rb`

Changed all development/debugging log statements from `.info` to `.debug`:

- Lines 36-38: params logging
- Line 51: Cleared session table_id
- Line 64: Table set from params
- Line 68: Table restored from session
- Line 72: Table cleared for fresh selection (THIS was spamming your logs!)
- Line 301: Session table_id set
- Lines 442-452: Placement method debug logs
- Line 495: create_event
- Line 518: Google Calendar response

**File**: `app/views/layouts/application.html.erb`

- **Line 12**: Removed HTML class setup logging (fired on EVERY page render)

### 3. Improved Error Logging

**File**: `app/controllers/locations_controller.rb`

- **Line 548**: Changed error logging to use `Rails.logger.error` instead of `.info`
- Limited backtrace to first 5 lines for readability

## Log Levels Explained

- **ERROR**: Serious problems requiring immediate attention
- **WARN**: Warnings about potential issues
- **INFO**: General informational messages about application flow
- **DEBUG**: Detailed debugging information (only in development)

In production with `config.log_level = "info"`, only ERROR, WARN, and INFO will be logged.
DEBUG statements are ignored, which is why changing to `.debug` reduces production logs.

## Expected Results

After deployment:

1. **No session data in logs** - Security improved
2. **No debug statements in production** - Log volume reduced by ~90%
3. **Still see important info**:
   - Request paths and methods
   - Response codes and timing
   - Actual errors and warnings

## Deployment Steps

```bash
# 1. Pull changes in BCW scenario
cd /Users/gullrich/DEV/carambus/carambus_bcw
git pull

# 2. Deploy via Capistrano
cd /Users/gullrich/DEV/carambus/carambus_master
rake "scenario:deploy[carambus_bcw]"

# 3. Restart server (if needed)
# SSH to server and: sudo systemctl restart puma-carambus_bcw
```

## Further Optimization (Optional)

If logs are still too verbose after this change, consider:

1. **Reduce Rails default logging** - Add custom middleware to filter out routine requests
2. **Configure lograge** - Structured one-line logging instead of multi-line
3. **Increase polling interval** - Change frontend auto-refresh from 20s to 30s or 60s
4. **Log rotation** - Ensure logrotate is configured properly

## Verification

After deployment, check logs:

```bash
tail -f ~/carambus_bcw/current/log/production.log
```

You should see:
- ✅ Request/response summary (normal)
- ✅ Errors and warnings
- ❌ No params logging
- ❌ No session data
- ❌ No emoji debug messages
- ❌ No HTML class setup messages
