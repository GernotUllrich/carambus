# RubyMine Setup Guide - Fix "Rails server launcher was not found"

## Error: "Rails server launcher was not found in a project"

This error occurs when RubyMine doesn't recognize your project as a Rails project. Follow these steps to fix it.

---

## 🔧 Solution Steps (In Order)

### Step 1: Invalidate Caches and Restart

1. **Open RubyMine**
2. Go to: **File** → **Invalidate Caches...**
3. Check: **Clear file system cache and Local History**
4. Click: **Invalidate and Restart**
5. Wait for RubyMine to restart and re-index

This often fixes the issue by forcing RubyMine to re-analyze the project structure.

---

### Step 2: Verify Ruby SDK Configuration

1. Go to: **RubyMine** → **Preferences** (or **Settings** on Windows/Linux)
   - Shortcut: `Cmd+,` (Mac) or `Ctrl+Alt+S` (Windows/Linux)
2. Navigate to: **Languages & Frameworks** → **Ruby SDK and Gems**
3. **Check if an SDK is selected:**
   - If no SDK: Click **+** and add your Ruby version
   - If SDK is listed: Make sure it's the correct version (check with `ruby -v` in terminal)
4. **Common SDK locations on macOS:**
   - Homebrew: `/usr/local/opt/ruby/bin/ruby` or `/opt/homebrew/opt/ruby/bin/ruby`
   - rbenv: `~/.rbenv/versions/{version}/bin/ruby`
   - rvm: `~/.rvm/rubies/{version}/bin/ruby`
5. Click **Apply** or **OK**

**To find your Ruby version:**
```bash
cd /Users/gullrich/carambus/carambus_master
ruby -v
which ruby
```

---

### Step 3: Configure Rails Framework Detection

1. In **Preferences/Settings**, go to: **Languages & Frameworks** → **Ruby on Rails**
2. **Verify these settings:**
   - **Rails version:** Should auto-detect (Rails ~> 7.2.0.beta2 for this project)
   - **Rails root:** Should point to `/Users/gullrich/carambus/carambus_master`
   - **Rails application root:** Same as Rails root
3. If Rails version is not detected:
   - Click **Detect** button
   - Or manually set: **Rails root** to your project directory
4. Click **Apply**

---

### Step 4: Reload Project from Disk

1. Go to: **File** → **Reload Project from Disk**
2. Wait for RubyMine to re-scan the project structure
3. Check if the error persists

---

### Step 5: Re-import as Rails Project (If Steps 1-4 Don't Work)

1. **Close RubyMine**
2. **Navigate to your project directory:**
   ```bash
   cd /Users/gullrich/carambus/carambus_master
   ```
3. **Open the project in RubyMine:**
   ```bash
   # Option 1: Open from RubyMine
   # File → Open → Select carambus_master folder
   
   # Option 2: From terminal (if installed via command line tools)
   mine .
   ```
4. **When RubyMine opens:**
   - It should ask: "Would you like to configure this project as a Rails application?"
   - Click **Yes** or **Configure**
   - If it doesn't ask, proceed to Step 6

---

### Step 6: Verify Project Structure

RubyMine needs to detect these Rails files:

**Required Files (should exist):**
- ✅ `Gemfile` (with `gem "rails"`)
- ✅ `config.ru`
- ✅ `Rakefile`
- ✅ `bin/rails`
- ✅ `config/application.rb`

**Check if these exist:**
```bash
cd /Users/gullrich/carambus/carambus_master
ls -la Gemfile config.ru Rakefile bin/rails config/application.rb
```

If any are missing, the project may not be properly set up.

---

### Step 7: Configure Deployment Server (After Fix)

Once RubyMine recognizes the Rails project:

1. Go to: **Tools** → **Deployment** → **Configuration**
2. Click **+** to add a new server
3. Choose your deployment type (e.g., **SFTP**, **Local**, **FTP**)
4. Configure server settings:
   - **Name:** Your server name
   - **Type:** SFTP (or your preferred type)
   - **Host:** Your server address
   - **Port:** SSH port (usually 22)
   - **User name:** Your SSH username
   - **Authentication:** Password or Key pair
5. **Test Connection** to verify it works
6. Click **OK**

---

### Step 8: Create Run Configuration for Rails Server

If you still need a Rails server configuration:

1. Go to: **Run** → **Edit Configurations...**
2. Click **+** → **Rails**
3. Configure:
   - **Name:** Rails Server
   - **Server:** Script: rails server
   - **Environment:** `RAILS_ENV=development`
   - **Port:** `3000` (or your preferred port)
4. Click **OK**

---

## 🚨 Troubleshooting

### Issue: "No SDK specified"

**Solution:**
```bash
# Find your Ruby installation
which ruby
# Add it in RubyMine: Preferences → Ruby SDK and Gems → + → Add SDK
```

---

### Issue: "Rails not detected"

**Solution:**
```bash
# Verify Rails is in your Gemfile
cd /Users/gullrich/carambus/carambus_master
grep rails Gemfile

# Install gems if needed
bundle install

# Check Rails version
bundle exec rails -v
```

Then in RubyMine: **Preferences** → **Ruby on Rails** → Click **Detect**

---

### Issue: Multiple Project Roots

If RubyMine is confused by the multi-project structure:

1. **Option 1:** Open `carambus_master` as the project root (not `carambus`)
2. **Option 2:** Configure project root:
   - **File** → **Project Structure** (or `Cmd+;`)
   - **Project Settings** → **Project**
   - **Project SDK:** Select your Ruby SDK
   - **Project compiler output:** Leave default or set to `tmp/rubymine/out`

---

### Issue: Still Not Working After All Steps

**Try this nuclear option:**

1. Close RubyMine
2. Delete RubyMine caches:
   ```bash
   rm -rf ~/Library/Caches/RubyMine*
   rm -rf ~/Library/Application\ Support/RubyMine*
   # Note: This will reset RubyMine settings, so backup if needed
   ```
3. Delete `.idea` folder in project (if exists):
   ```bash
   cd /Users/gullrich/carambus/carambus_master
   rm -rf .idea
   ```
4. Reopen project in RubyMine
5. Re-configure SDK and Rails settings

---

## ✅ Verification

After fixing, verify RubyMine recognizes Rails:

1. **Check Project Structure:**
   - Right-click on project root → **Show in Explorer** → Should show Rails structure
   
2. **Check Rails Detection:**
   - **Preferences** → **Ruby on Rails** → Should show Rails version (e.g., "7.2.0.beta2")

3. **Try Deployment Configuration:**
   - **Tools** → **Deployment** → **Configuration**
   - Error should be gone

4. **Check Rails Console:**
   - **Tools** → **Run Rails Console** → Should work

---

## 📝 Quick Checklist

- [ ] Invalidated caches and restarted
- [ ] Ruby SDK is configured correctly
- [ ] Rails framework is detected
- [ ] Project reloaded from disk
- [ ] Deployment configuration can be opened without errors

---

## 🔗 Additional Resources

- [RubyMine Documentation - Rails Support](https://www.jetbrains.com/help/ruby/rails.html)
- [RubyMine Documentation - Deployment](https://www.jetbrains.com/help/ruby/deployment.html)

---

**Last Updated:** 2025-01-28  
**RubyMine Version:** Check your version: **RubyMine** → **About RubyMine**

