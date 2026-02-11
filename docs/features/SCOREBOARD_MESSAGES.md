# Scoreboard Messages Feature

## Overview

The Scoreboard Messages feature allows administrators to send popup messages to scoreboards that must be acknowledged by users before they can continue. Messages can be sent to specific tables or to all tables in a location.

## Features

- ✅ Send messages to specific tables or all tables in a location
- ✅ Messages appear as modal popups that require acknowledgement
- ✅ Acknowledging on one table dismisses on all tables
- ✅ Auto-expire after 30 minutes
- ✅ Real-time delivery via ActionCable
- ✅ Admin interface for message management
- ✅ Only accessible to `club_admin` and `system_admin` roles

## User Guide

### Sending a Message

1. Navigate to **Admin > Scoreboard Messages**
2. Click **"Send New Message"**
3. Fill in the form:
   - **Location**: Select the location (required)
   - **Target Table**: Leave empty for all tables, or select a specific table
   - **Message**: Enter your message (max 500 characters)
4. Click **"Send Message"**

The message will appear immediately on all active scoreboards at the selected location.

### Message Lifecycle

```
Created → Broadcast → Displayed → Acknowledged → Dismissed
    ↓                                              ↑
    └─────────── Auto-expire (30 min) ───────────┘
```

### Viewing Messages

- **Index Page**: Shows all messages with status filters (Active, Acknowledged, Expired)
- **Show Page**: Detailed view of a single message
- **Status Indicators**:
  - 🟡 **Active**: Message is currently displayed and waiting for acknowledgement
  - 🟢 **Acknowledged**: Message was acknowledged by a user
  - 🔴 **Expired**: Message reached its 30-minute timeout without acknowledgement

## Technical Implementation

### Database Schema

```ruby
create_table :scoreboard_messages do |t|
  t.integer :table_monitor_id     # nil = broadcast to all tables
  t.integer :location_id, null: false
  t.text :message, null: false
  t.datetime :acknowledged_at
  t.datetime :expires_at          # auto-dismiss after 30 minutes
  t.integer :sender_id, null: false
  t.timestamps
end
```

### Architecture

```
Admin Interface (Web)
         ↓
  ScoreboardMessage Model
         ↓
  ActionCable Broadcast
         ↓
  TableMonitorChannel (WebSocket)
         ↓
  Scoreboard Frontend (Modal)
         ↓
  User Acknowledgement → POST /scoreboard_messages/:id/acknowledge
         ↓
  ActionCable Broadcast (hide message on all scoreboards)
```

### Key Components

1. **Model**: `app/models/scoreboard_message.rb`
   - Validations and business logic
   - Broadcast methods
   - Scopes: `active`, `expired`, `acknowledged`

2. **Controllers**:
   - `Admin::ScoreboardMessagesController` - Admin CRUD interface
   - `ScoreboardMessagesController` - Public acknowledgement endpoint

3. **Views**:
   - Admin views in `app/views/admin/scoreboard_messages/`
   - Modal partial in `app/views/shared/_scoreboard_message_modal.html.erb`

4. **JavaScript**:
   - Stimulus controller: `app/javascript/controllers/scoreboard_message_controller.js`
   - Channel integration: `app/javascript/channels/table_monitor_channel.js`

5. **Jobs**:
   - `ScoreboardMessageCleanupJob` - Auto-acknowledge expired messages

### ActionCable Message Types

**1. New Message Broadcast**
```javascript
{
  type: 'scoreboard_message',
  message_id: 123,
  table_monitor_id: 456,
  message: 'Please close the doors',
  expires_at: '2026-02-11T19:00:00Z'
}
```

**2. Acknowledgement Broadcast**
```javascript
{
  type: 'scoreboard_message_acknowledged',
  message_id: 123,
  table_monitor_id: 456,
  reason: 'user_acknowledged' | 'auto_expired'
}
```

## Maintenance

### Automatic Cleanup

Messages are automatically cleaned up after expiration. Set up a cron job:

```bash
# Clean up expired messages every 10 minutes
*/10 * * * * cd /path/to/carambus && bundle exec rake scoreboard_messages:cleanup RAILS_ENV=production >> log/scoreboard_messages.log 2>&1
```

### Rake Tasks

```bash
# Clean up expired messages
rake scoreboard_messages:cleanup

# List active messages
rake scoreboard_messages:list

# Show statistics
rake scoreboard_messages:stats
```

### Monitoring

```ruby
# Rails console
ScoreboardMessage.active.count           # Active messages
ScoreboardMessage.expired.count          # Expired but not acknowledged
ScoreboardMessage.acknowledged.count     # Total acknowledged
```

## Permissions

Only users with the following roles can send messages:
- `club_admin`
- `system_admin`

Check is performed in `Admin::ScoreboardMessagesController#check_permissions`

## Frontend Integration

The modal is automatically included in the main layout when `@table_monitor` is present:

```erb
<!-- app/views/layouts/application.html.erb -->
<%= render partial: "shared/scoreboard_message_modal" if @table_monitor.present? %>
```

The Stimulus controller is initialized via the `data-controller="scoreboard-message"` attribute on the modal element.

## Security Considerations

1. **CSRF Protection**: Skip for acknowledgement endpoint (scoreboard may not have token)
2. **Authorization**: Admin actions protected by `check_permissions` before_action
3. **XSS Prevention**: Message text is escaped in views
4. **Rate Limiting**: Consider adding rate limiting for message creation (future enhancement)

## Future Enhancements

- [ ] Message priority levels (info, warning, critical)
- [ ] Message templates for common notifications
- [ ] Message history and analytics
- [ ] Multi-language support for messages
- [ ] Rich text formatting in messages
- [ ] Sound notification on message arrival
- [ ] Configurable expiry times per message

## Testing

### Manual Testing Steps

1. **Send to Specific Table**:
   - Create message for Table 1
   - Verify it appears on Table 1's scoreboard
   - Verify it does NOT appear on Table 2's scoreboard

2. **Send to All Tables**:
   - Create message with no table selection
   - Verify it appears on all active scoreboards

3. **Acknowledge and Dismiss**:
   - Display message on multiple scoreboards
   - Acknowledge on one scoreboard
   - Verify it disappears from all scoreboards

4. **Auto-Expiry**:
   - Create message
   - Wait 30 minutes (or adjust expires_at in console)
   - Run cleanup job
   - Verify message disappears

### Console Testing

```ruby
# Create a test message
location = Location.first
sender = User.find_by(role: :system_admin)
message = ScoreboardMessage.create!(
  location: location,
  message: "Test message",
  sender: sender
)

# Broadcast to scoreboards
message.broadcast_to_scoreboards

# Acknowledge
message.acknowledge!

# Check status
message.active?        # => false
message.acknowledged?  # => true
```

## Troubleshooting

### Message not appearing on scoreboard

1. Check ActionCable connection in browser console
2. Verify scoreboard is subscribed to `table-monitor-stream`
3. Check message was broadcast: `rails console` → `ScoreboardMessage.last.broadcast_to_scoreboards`
4. Verify modal element exists: `document.querySelector('[data-controller="scoreboard-message"]')`

### Acknowledgement not working

1. Check browser console for JavaScript errors
2. Verify CSRF token is present in page
3. Check route is accessible: `POST /scoreboard_messages/:id/acknowledge`
4. Verify ActionCable broadcasts acknowledgement

### Messages not auto-expiring

1. Verify cleanup job is running: `ScoreboardMessageCleanupJob.perform_now`
2. Check cron job is configured
3. Verify expires_at is set correctly on messages
4. Check job logs: `log/scoreboard_messages.log`

## Support

For issues or questions, contact the development team or consult the main Carambus documentation.
