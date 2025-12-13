# Gmail SMTP Setup Summary

## Changes Made

All configurations have been updated to use **Gmail SMTP** instead of GMX.

### Configuration Files Updated

1. **`config/environments/production-bc-wedel.rb`**
   - SMTP server: `smtp.gmail.com`
   - Port: 587 (TLS)
   - Domain: `bc-wedel.de`
   - Credentials via environment variables

2. **`config/environments/production-carambus-de.rb`**
   - SMTP server: `smtp.gmail.com`
   - Port: 587 (TLS)
   - Domain: `carambus.de`
   - Credentials via environment variables

3. **`config/initializers/devise.rb`**
   - Mailer sender now uses `ENV['SMTP_USERNAME']`
   - Falls back to `no-reply@carambus.de` if not set

### Documentation Updated

- `QUICK_FIX_EMAIL.md` - Gmail instructions
- `EMAIL_CONFIGURATION_FIX.md` - Gmail setup details
- `docs/email_configuration.de.md` - German Gmail guide
- `docs/email_configuration.en.md` - English Gmail guide

## Gmail App Password Setup (CRITICAL)

### Prerequisites

**Gmail requires 2-Step Verification to create app passwords!**

1. **Enable 2-Step Verification:**
   - Visit: https://myaccount.google.com/security
   - Click "2-Step Verification"
   - Follow the setup wizard (phone verification required)

2. **Create App Password:**
   - Visit: https://myaccount.google.com/apppasswords
   - Select app: "Mail"
   - Select device: "Other (Custom name)" → Enter "Carambus"
   - Click "Generate"
   - **Copy the 16-character password immediately!**
   
   ```
   Example displayed: abcd efgh ijkl mnop
   Use without spaces:  abcdefghijklmnop
   ```

### Important Notes

- ❌ **Do NOT use your regular Gmail password**
- ✅ **Do use a 16-character app password**
- ❌ **Do NOT include spaces** in the app password
- ✅ **Do keep the password safe** - you can't view it again
- ✅ **Do create a new one** if you lose it

## Deployment Steps

### Step 1: Get Your Gmail App Password

Follow the prerequisites above to obtain your 16-character app password.

### Step 2: Set Environment Variables on Production Server

```bash
# SSH to production server
ssh www-data@<server-ip> -p <port>

# Edit .bashrc
nano ~/.bashrc

# Add these lines (replace with your actual email and app password):
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="abcdefghijklmnop"

# Save and reload
source ~/.bashrc

# Verify
echo $SMTP_USERNAME
echo $SMTP_PASSWORD
```

### Step 3: Update Systemd Service

```bash
# Edit service file (adjust service name for your deployment)
sudo nano /etc/systemd/system/carambus_bcw.service

# Find the [Service] section and add:
[Service]
...
Environment="SMTP_USERNAME=your-email@gmail.com"
Environment="SMTP_PASSWORD=abcdefghijklmnop"
...

# Save, reload, and restart
sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw
sudo systemctl status carambus_bcw
```

### Step 4: Pull Code Changes

```bash
cd ~/carambus_bcw/current
git pull origin master
```

### Step 5: Test Email

```bash
cd ~/carambus_bcw/current
RAILS_ENV=production bundle exec rails console

# Test email
ActionMailer::Base.mail(
  from: ENV['SMTP_USERNAME'],
  to: ENV['SMTP_USERNAME'],
  subject: 'Carambus Gmail Test',
  body: 'If you receive this, Gmail SMTP is working!'
).deliver_now

# Should complete without errors
# Check your Gmail inbox
exit
```

### Step 6: Test User Registration

1. Open browser to your Carambus instance
2. Navigate to: `/users/sign_up`
3. Register a new test user
4. Should complete without timeout
5. Check email for confirmation link

## Troubleshooting

### Error: "Invalid credentials"

```ruby
Net::SMTPAuthenticationError: 535-5.7.8 Username and Password not accepted
```

**Solutions:**
- Ensure 2-Step Verification is enabled
- Use app password, not regular password
- Remove spaces from app password
- Create a new app password
- Verify `SMTP_USERNAME` is full email address

### Error: "Connection refused"

```ruby
Errno::ECONNREFUSED: Connection refused - connect(2) for "smtp.gmail.com" port 587
```

**Solutions:**
- Check firewall allows outbound port 587
- Try alternative port 465 (SSL):
  ```ruby
  config.action_mailer.smtp_settings = {
    address: 'smtp.gmail.com',
    port: 465,
    # ... rest of config
  }
  ```

### Error: "Timeout"

```ruby
Net::ReadTimeout: Net::ReadTimeout
```

**Solutions:**
- Check internet connectivity
- Verify DNS resolves `smtp.gmail.com`
- Increase timeout values if network is slow

### Environment Variables Not Set

```bash
# Check if variables are set
echo $SMTP_USERNAME
echo $SMTP_PASSWORD

# If empty, reload environment
source ~/.bashrc

# Check systemd service has variables
sudo systemctl show carambus_bcw -p Environment
```

## Gmail vs GMX Differences

| Feature | Gmail | GMX (old) |
|---------|-------|-----------|
| SMTP Server | smtp.gmail.com | mail.gmx.net |
| Requires 2FA | Yes (mandatory) | No |
| App Password | 16 chars, no spaces | Variable length |
| Port | 587 (TLS) | 587 (TLS) |
| Reliability | Excellent | Good |
| Setup Complexity | Moderate (2FA required) | Simple |

## Why Gmail?

1. **More Reliable** - Google's infrastructure is more robust
2. **Better Deliverability** - Less likely to be marked as spam
3. **Established** - You're already using Gmail
4. **Free** - No cost for sending emails
5. **Widely Supported** - Standard SMTP implementation

## Security Considerations

✅ **Best Practices:**
- Use environment variables for credentials
- Never commit passwords to Git
- Use app passwords, not account passwords
- Rotate app passwords periodically
- Use TLS encryption (port 587)

❌ **Don't:**
- Hard-code credentials in config files
- Share app passwords
- Reuse app passwords across applications
- Use unencrypted SMTP (port 25)

## Files Changed

```
config/environments/production-bc-wedel.rb
config/environments/production-carambus-de.rb
config/initializers/devise.rb
docs/email_configuration.de.md
docs/email_configuration.en.md
EMAIL_CONFIGURATION_FIX.md
QUICK_FIX_EMAIL.md
GMAIL_SETUP_SUMMARY.md (this file)
```

## Next Steps

1. ✅ Code changes complete (ready to commit)
2. ⏳ Create Gmail app password
3. ⏳ Deploy to production servers
4. ⏳ Configure environment variables
5. ⏳ Test email sending
6. ⏳ Monitor production logs

## Support

If you encounter issues:
1. Check production logs: `tail -f ~/carambus_bcw/current/log/production.log`
2. Review documentation: `EMAIL_CONFIGURATION_FIX.md`
3. Test SMTP manually: `telnet smtp.gmail.com 587`
4. Verify environment variables are set
5. Check systemd service status

## References

- Gmail App Passwords: https://myaccount.google.com/apppasswords
- Gmail SMTP Settings: https://support.google.com/mail/answer/7126229
- Rails ActionMailer: https://guides.rubyonrails.org/action_mailer_basics.html
- Devise Configuration: https://github.com/heartcombo/devise

