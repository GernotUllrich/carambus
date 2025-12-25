# Email Configuration

## Overview

Carambus uses email for:
- User registration (confirmation emails)
- Password reset
- Account invitations
- Notifications

## Production Environment - SMTP Configuration

### Problem with Sendmail

The original configuration used `sendmail`, which often leads to timeouts on Raspberry Pi servers because:
- Sendmail/Postfix is not correctly configured
- The service is not running properly
- Timeouts block user registration

### Solution: SMTP (Gmail)

Production environments are now switched to SMTP:

**Files:**
- `config/environments/production-bc-wedel.rb`
- `config/environments/production-carambus-de.rb`

**Configuration:**
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

## Setting up Environment Variables

### On Production Server

SSH to the server and set the environment variables:

```bash
# As www-data user
sudo -u www-data -i

# Set environment variables in .bashrc or .profile
echo 'export SMTP_USERNAME="your-email@gmail.com"' >> ~/.bashrc
echo 'export SMTP_PASSWORD="your-app-password"' >> ~/.bashrc

# Reload
source ~/.bashrc
```

### For Systemd Service

If Puma runs as a systemd service, variables must be set in the service file:

```bash
sudo nano /etc/systemd/system/carambus_bcw.service
```

Add under `[Service]`:
```ini
Environment="SMTP_USERNAME=your-email@gmail.com"
Environment="SMTP_PASSWORD=your-app-password"
```

Reload service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw
```

## Creating a Gmail App Password

**Important:** Don't use a regular Gmail password, but an app password!

### Prerequisite: 2-Step Verification

Gmail app passwords require 2-Step Verification to be enabled:

1. Go to: https://myaccount.google.com/security
2. Click "2-Step Verification"
3. Follow the setup instructions

### Create App Password

1. Go to: https://myaccount.google.com/apppasswords
   - Or: Google Account → Security → 2-Step Verification → App passwords
2. Select app: "Mail"
3. Select device: "Other (Custom name)" → Enter "Carambus"
4. Click "Generate"
5. **Copy the 16-character password** (without spaces!)
   - Displayed: `abcd efgh ijkl mnop`
   - Use: `abcdefghijklmnop`
6. Use as `SMTP_PASSWORD`

## Testing

### Manual Test in Rails Console

```bash
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

# Send test email
ActionMailer::Base.mail(
  from: ENV['SMTP_USERNAME'],
  to: ENV['SMTP_USERNAME'],
  subject: 'Test Email',
  body: 'This is a test'
).deliver_now
```

### Test User Registration

1. Open the registration page
2. Create a new user
3. Check logs for errors:
   ```bash
   tail -f ~/carambus_bcw/current/log/production.log
   ```

## Troubleshooting

### Timeout Errors

**Symptom:**
```
Net::ReadTimeout (Net::ReadTimeout with #<TCPSocket:(closed)>)
```

**Causes:**
- SMTP server unreachable
- Firewall blocking port 587
- Wrong SMTP credentials
- `SMTP_PASSWORD` environment variable not set

**Solution:**
```bash
# Test SMTP connection
telnet smtp.gmail.com 587

# Check environment variables
echo $SMTP_PASSWORD

# Check logs
tail -100 ~/carambus_bcw/current/log/production.log
```

### Authentication Errors

**Symptom:**
```
Net::SMTPAuthenticationError
```

**Solution:**
- Use a Gmail app password (16 characters, no spaces)
- Check if username is correct (full email address)
- Make sure 2-Step Verification is enabled
- Create a new app password if unsure

### Port Blocked

**Symptom:**
```
Errno::ECONNREFUSED (Connection refused)
```

**Solution:**
```bash
# Test port 587
sudo netstat -tuln | grep 587

# Test alternative ports
# Port 465 (SSL): config.action_mailer.smtp_settings[:port] = 465
# Port 25 (unencrypted, not recommended)
```

## Alternative: Fix Sendmail (not recommended)

If you still want to use sendmail:

```bash
# Install Postfix
sudo apt-get install postfix

# Configure Postfix as Internet Site
sudo dpkg-reconfigure postfix

# Start service
sudo systemctl enable postfix
sudo systemctl start postfix

# Test
echo "Test" | mail -s "Test Subject" gernot.ullrich@gmx.de
```

**Problem:** Many ISPs block port 25, so outgoing emails won't work.

## Security Notes

1. **Never commit passwords to Git**
2. Always use environment variables for credentials
3. Use app passwords instead of regular passwords
4. Set `enable_starttls_auto: true` for encrypted connections

## Deployment

After changes to environment files:

```bash
# In carambus_master
git add config/environments/production-*.rb
git commit -m "Switch from sendmail to SMTP for email delivery"
git push

# On production server
cd ~/carambus_bcw/current
git pull
sudo systemctl restart carambus_bcw
```

## See Also

- [Deployment Workflow](../developers/deployment-workflow.en.md)
- [Server Architecture](server-architecture.en.md)
- [Scenario Management](../developers/scenario-management.en.md)

