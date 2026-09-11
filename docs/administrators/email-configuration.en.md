# Email Configuration

## Overview

Carambus uses email for:
- User registration (confirmation emails)
- Password reset
- Account invitations
- Notifications

## Production Environment - SMTP Configuration

### Why SMTP instead of Sendmail

Earlier configurations used `sendmail`, which often caused timeouts on Raspberry Pi servers because:
- Sendmail/Postfix was not configured correctly
- The service was not running properly
- Timeouts blocked user registration

### SMTP (Gmail)

All production environments send via SMTP through Gmail. Each instance's `production.rb` is **generated**:
`scenario:prepare_deploy` or `scenario:generate_configs` create it from `lib/tasks/scenarios.rake`
(`generate_production_rb_env`); on the server it lives at
`/var/www/<basename>/shared/config/environments/production.rb`.

**Generated block:**
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.gmail.com",
  port: 587,
  domain: "carambus.de",
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  authentication: "plain",
  enable_starttls_auto: true,
  open_timeout: 5,
  read_timeout: 5
}
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_options = { from: ENV["SMTP_USERNAME"] || "no-reply@carambus.de" }
```

## Setting up Credentials

### Via Scenario Management

Puma runs as the systemd service `puma-<basename>` and reads the credentials **only** from
`/etc/<basename>.env` (`EnvironmentFile=` in `templates/puma/puma.service.erb`). A `.bashrc` or `.profile`
does not reach the service.

1. Enter the credentials in `carambus_data/secrets.yml` (not versioned):
   ```yaml
   shared:
     smtp:
       username: "...@gmail.com"
       password: "..."          # Gmail: app password, not the account password
   # or for one scenario only:
   per_scenario:
     <scenario>:
       smtp:
         username: "..."
         password: "..."
   ```
2. From the admin machine, in a carambus checkout:
   ```bash
   bin/rails "scenario:prepare_deploy[<scenario>]"
   ```
   `prepare_deploy` creates `/etc/<basename>.env` (mode 600, owner root) if the file is missing. Without
   SMTP credentials and without `smtp_enabled: false` the task aborts with instructions.

Do **not edit** the systemd unit `puma-<basename>.service` itself: `prepare_deploy` rewrites it on every run.

### Changing the Credentials

`prepare_deploy` never overwrites an existing `/etc/<basename>.env`. To change it on the server:

```bash
sudo nano /etc/<basename>.env
sudo systemctl restart puma-<basename>
```

### Servers without real SMTP: `SKIP_SMTP_GUARD`

In production, `config/initializers/smtp_guard.rb` checks at server/Sidekiq boot whether
`SMTP_USERNAME` and `SMTP_PASSWORD` are set, and deliberately aborts startup otherwise
(fail-fast, so Devise emails don't fail silently). Internal or scenario servers that need
**no real SMTP** (e.g. `carambus_gu`) set the opt-out flag instead — cleaner than storing
dummy SMTP credentials.

The way to do this is the scenario's `config.yml`:

```yaml
environments:
  production:
    smtp_enabled: false
```

`prepare_deploy` then writes `SKIP_SMTP_GUARD=1` into `/etc/<basename>.env`. If the file already exists, add
the line there by hand and restart `puma-<basename>`.

When `SKIP_SMTP_GUARD` is set, the guard is skipped and the server boots without SMTP
credentials. **Without** the flag, the fail-fast protection stays active as before — so omit
it on real mail-sending servers.

## Creating a Gmail App Password

**Important:** Don't use your regular Gmail password, use an app password instead!

### Prerequisite: 2-Step Verification

Gmail app passwords require 2-step verification to be enabled:

1. Go to: https://myaccount.google.com/security
2. Click on "2-Step Verification"
3. Follow the instructions to enable it

### Create App Password

1. Go to: https://myaccount.google.com/apppasswords
   - Or: Google Account → Security → 2-Step Verification → App passwords
2. Select app: "Mail"
3. Select device: "Other (Custom name)" → Enter "Carambus"
4. Click "Generate"
5. **Copy the 16-character password** (without spaces!)
   - Displayed: `abcd efgh ijkl mnop`
   - Use: `abcdefghijklmnop`
6. Enter it as `password` under `smtp` in `secrets.yml`

## Testing

### Manual Test in Rails Console

The console does not run under systemd and therefore does not know `SMTP_USERNAME`/`SMTP_PASSWORD`. Take
the values for the session from the (root-only) file:

```bash
ssh -p 8910 www-data@<server>
cd /var/www/<basename>/current
set -a; eval "$(sudo cat /etc/<basename>.env)"; set +a
RAILS_ENV=production bin/rails console

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
   tail -f /var/www/<basename>/shared/log/production.log
   ```

## Troubleshooting

### Puma does not start, nginx reports 502

**Symptom:** `FATAL: SMTP-ENV nicht gesetzt` in the journal.

```bash
sudo journalctl -u puma-<basename> -n 40 --no-pager
```

**Solution:** `/etc/<basename>.env` is missing or incomplete. Add the SMTP credentials to `secrets.yml` and run
`prepare_deploy` again (it creates the file if missing), or complete the file by hand and restart
`puma-<basename>`.

### Timeout Errors

**Symptom:**
```
Net::ReadTimeout (Net::ReadTimeout with #<TCPSocket:(closed)>)
```

**Causes:**
- SMTP server not reachable
- Firewall blocks port 587
- Wrong SMTP credentials

**Solution:**
```bash
# Test SMTP connection
telnet smtp.gmail.com 587

# Check that the credentials are set (don't paste the values into tickets)
sudo cat /etc/<basename>.env

# Check logs
tail -100 /var/www/<basename>/shared/log/production.log
```

### Authentication Errors

**Symptom:**
```
Net::SMTPAuthenticationError
```

**Solution:**
- Use a Gmail app password (16 characters, no spaces)
- Check that username is correct (full email address)
- Make sure 2-step verification is enabled
- Create a new app password if unsure

### Port Blocked

**Symptom:**
```
Errno::ECONNREFUSED (Connection refused)
```

**Solution:**
```bash
# Test the connection to port 587
nc -vz smtp.gmail.com 587
```

Port 465 (SSL) or 25 (unencrypted, not recommended) would be a change to the generated block, i.e. to the
generator in `lib/tasks/scenarios.rake`.

## Alternative: Fix Sendmail (not recommended)

If you still want to use Sendmail:

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

**Problem:** Many ISPs block port 25, so outgoing emails don't work.

## Security Notes

1. **Never commit passwords to Git**: credentials live only in `carambus_data/secrets.yml` (not versioned)
   and on the server in `/etc/<basename>.env` (mode 600)
2. Use app passwords instead of regular passwords
3. `enable_starttls_auto: true` is part of the generated block

## Deployment

Changes to the SMTP block belong in the generator, not in a file under `config/environments/`:

```bash
# In any up-to-date carambus checkout
# adjust lib/tasks/scenarios.rake (generate_production_rb_env), then
git add lib/tasks/scenarios.rake
git commit -m "..."
git pull --rebase origin master && git push origin master

# Regenerate and roll out the configuration (from the admin machine)
bin/rails "scenario:prepare_deploy[<scenario>]"
bin/rails "scenario:deploy[<scenario>]"
```

On the server, `current` is an unpacked release without Git; no `git pull` there. For a changed
`/etc/<basename>.env` alone, `sudo systemctl restart puma-<basename>` on the server is enough.

## See Also

- [Deployment Workflow](../developers/deployment-workflow.md)
- [Server Architecture](server-architecture.md)
- [Scenario Management](../developers/scenario-management.md)
- [Raspberry Pi Quickstart, section 3.1](raspberry-pi-quickstart.md)
