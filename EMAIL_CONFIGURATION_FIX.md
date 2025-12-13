# Email Configuration Fix - User Registration Timeout

## Problem

User registration was failing with a `Net::ReadTimeout` error after ~5 seconds when trying to send confirmation emails via sendmail/postfix on the Raspberry Pi production server (carambus_bcw).

**Error Log:**
```
Net::ReadTimeout (Net::ReadTimeout with #<TCPSocket:(closed)>)
```

**Root Cause:**
- Postfix service on Raspberry Pi was not properly configured
- The systemd service showed status "active (exited)" but was running `/bin/true` (dummy command)
- Email delivery timeouts were blocking user registration
- User records were created successfully but confirmation emails failed to send

## Solution

Switched from `sendmail` to **SMTP (Gmail)** for more reliable email delivery.

## Changes Made

### 1. Updated Production Environment Configs

**Files Modified:**
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/config/environments/production-bc-wedel.rb`
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/config/environments/production-carambus-de.rb`

**Changed from:**
```ruby
config.action_mailer.delivery_method = :sendmail
```

**Changed to:**
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'bc-wedel.de',  # or 'carambus.de'
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true,
  open_timeout: 5,
  read_timeout: 5
}
```

### 2. Created Documentation

- `docs/email_configuration.de.md` - German documentation
- `docs/email_configuration.en.md` - English documentation

Both documents include:
- Configuration explanation
- Environment variable setup
- GMX app password creation
- Testing procedures
- Troubleshooting guide

## Deployment Steps

### 1. Commit and Push Changes

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

git add config/environments/production-bc-wedel.rb
git add config/environments/production-carambus-de.rb
git add docs/email_configuration.de.md
git add docs/email_configuration.en.md
git add EMAIL_CONFIGURATION_FIX.md

git commit -m "Fix: Switch from sendmail to SMTP (Gmail) for email delivery

- Change production environments to use Gmail SMTP instead of sendmail
- Fixes Net::ReadTimeout errors during user registration
- Add comprehensive email configuration documentation
- Use environment variables for SMTP credentials
- Update Devise mailer_sender to use environment variable"

git push
```

### 2. Create Gmail App Password

**Important:** Requires 2-Step Verification to be enabled first!

1. Enable 2-Step Verification (if not already enabled):
   - Go to: https://myaccount.google.com/security
   - Click "2-Step Verification" and complete setup

2. Create App Password:
   - Go to: https://myaccount.google.com/apppasswords
   - Select app: "Mail"
   - Select device: "Other (Custom name)" → "Carambus"
   - Click "Generate"
   - **Copy the 16-character password** (displayed with spaces, use without spaces)
   - Example: `abcd efgh ijkl mnop` → Use as: `abcdefghijklmnop`

### 3. Configure Production Server (carambus_bcw)

```bash
# SSH to the production server
ssh www-data@192.168.178.xxx -p 8910

# Navigate to the application
cd ~/carambus_bcw/current

# Pull the latest changes
git pull origin master

# Set environment variables (use your Gmail address and app password from step 2)
nano ~/.bashrc

# Add these lines at the end:
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-16-char-app-password"

# Save and exit (Ctrl+X, Y, Enter)

# Reload environment
source ~/.bashrc

# Verify variables are set
echo $SMTP_PASSWORD
```

### 4. Update Systemd Service

```bash
# Edit the service file
sudo nano /etc/systemd/system/carambus_bcw.service

# Add under [Service] section:
Environment="SMTP_USERNAME=your-email@gmail.com"
Environment="SMTP_PASSWORD=your-16-char-app-password"

# Save and exit

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw

# Check status
sudo systemctl status carambus_bcw
```

### 5. Test Email Sending

```bash
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

# In Rails console:
ActionMailer::Base.mail(
  from: ENV['SMTP_USERNAME'],
  to: ENV['SMTP_USERNAME'],
  subject: 'Carambus Email Test',
  body: 'Test email after SMTP configuration'
).deliver_now

# Should return without errors
# Check your email inbox
exit
```

### 6. Test User Registration

1. Open browser to: https://bc-wedel.de (or appropriate URL)
2. Go to user registration page
3. Create a test user
4. Should complete successfully
5. Check email for confirmation link
6. Monitor logs:
   ```bash
   tail -f ~/carambus_bcw/current/log/production.log
   ```

## Repeat for Other Production Servers

Apply the same steps to:
- carambus_api production server
- Any other production deployments

Each server needs:
1. Git pull to get updated environment files
2. SMTP environment variables configured
3. Systemd service updated with environment variables
4. Service restart
5. Testing

## Rollback Plan

If SMTP doesn't work, you can temporarily disable email sending:

```ruby
# In config/environments/production-*.rb
config.action_mailer.perform_deliveries = false
```

Or revert to sendmail:
```ruby
config.action_mailer.delivery_method = :sendmail
```

## Verification Checklist

- [ ] Changes committed and pushed from carambus_master
- [ ] GMX app password created
- [ ] Environment variables set in ~/.bashrc
- [ ] Environment variables set in systemd service
- [ ] Service reloaded and restarted
- [ ] Test email sent successfully from Rails console
- [ ] User registration works without timeout
- [ ] Confirmation email received
- [ ] Documentation accessible in mkdocs

## Technical Details

**Email Flow:**
1. User registers → RegistrationsController#create
2. Devise creates user with `:confirmable`
3. Devise triggers confirmation email via ActionMailer
4. ActionMailer uses SMTP settings to connect to smtp.gmail.com:587
5. Email sent via TLS-encrypted connection
6. User receives confirmation email

**Timeout Settings:**
- `open_timeout: 5` - Max 5 seconds to open connection
- `read_timeout: 5` - Max 5 seconds to read response
- `enable_starttls_auto: true` - Use TLS encryption

**Security:**
- App passwords are more secure than regular passwords
- TLS encryption protects email transmission
- Environment variables keep credentials out of Git
- Systemd service environment is isolated per deployment

## Related Files

- `app/models/user.rb` - User model with `:confirmable`
- `config/initializers/devise.rb` - Devise configuration
- `app/mailers/application_mailer.rb` - Base mailer class
- `app/controllers/registrations_controller.rb` - User registration

## See Also

- [docs/email_configuration.de.md](docs/email_configuration.de.md)
- [docs/email_configuration.en.md](docs/email_configuration.en.md)
- [docs/deployment_workflow.de.md](docs/deployment_workflow.de.md)

