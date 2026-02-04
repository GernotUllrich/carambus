# Quick Fix - Email Configuration (User Registration Timeout)

## Problem
User registration times out when trying to send confirmation email.

## Solution Summary
Switched from sendmail to SMTP (Gmail).

## Quick Deployment Steps

### 1. Get Gmail App Password (5 minutes)

**Important:** Gmail requires 2-Step Verification to be enabled first!

1. Enable 2-Step Verification:
   - Go to: https://myaccount.google.com/security
   - Click "2-Step Verification" and follow the setup

2. Create App Password:
   - Go to: https://myaccount.google.com/apppasswords
   - Or: Google Account → Security → 2-Step Verification → App passwords
   - Select app: "Mail"
   - Select device: "Other (Custom name)" → Enter "Carambus"
   - Click "Generate"
   - **Copy the 16-character password** (no spaces, you can't view it again!)

Example: `abcd efgh ijkl mnop` → Use as: `abcdefghijklmnop`

### 2. Deploy to carambus_bcw (10 minutes)

```bash
# On your Mac - Commit changes
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git add config/environments/production-*.rb docs/email_configuration.*.md *.md
git commit -m "Fix: Switch to SMTP for email delivery"
git push

# SSH to production server
ssh www-data@<bcw-server-ip> -p 8910

# Pull changes
cd ~/carambus_bcw/current
git pull origin master

# Set environment variables (replace with your Gmail address and app password from step 1)
cat >> ~/.bashrc << 'EOF'
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-16-char-app-password"
EOF

source ~/.bashrc

# Update systemd service
sudo nano /etc/systemd/system/carambus_bcw.service

# Add these two lines in the [Service] section:
#   Environment="SMTP_USERNAME=your-email@gmail.com"
#   Environment="SMTP_PASSWORD=your-16-char-app-password"

# Restart
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw
sudo systemctl status carambus_bcw
```

### 3. Quick Test

```bash
# Test from Rails console
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

# Send test email (use your Gmail address)
ActionMailer::Base.mail(from: ENV['SMTP_USERNAME'], to: ENV['SMTP_USERNAME'], subject: 'Test', body: 'Test').deliver_now

# Exit console
exit

# Test user registration on website
# https://bc-wedel.de/users/sign_up
```

## Troubleshooting

### Email not sending?
```bash
# Check environment variables are set
echo $SMTP_PASSWORD

# Check logs
tail -50 ~/carambus_bcw/current/log/production.log | grep -i mail
```

### Still getting timeout?
- Check firewall allows port 587 outbound
- Verify Gmail app password is correct (16 characters, no spaces)
- Make sure 2-Step Verification is enabled on Google account
- Check "Less secure app access" is NOT blocking (shouldn't be needed with app passwords)
- Try port 465 instead of 587 in config if needed

## Files Changed
- `config/environments/production-bc-wedel.rb`
- `config/environments/production-carambus-de.rb`
- `docs/email_configuration.de.md` (NEW)
- `docs/email_configuration.en.md` (NEW)

## Full Documentation
See: `EMAIL_CONFIGURATION_FIX.md` for complete details.

