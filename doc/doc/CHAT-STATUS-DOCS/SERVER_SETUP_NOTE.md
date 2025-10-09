# 🚨 Server Setup Note: PID Conflicts

## Issue
When running Rails server for testing, there can be PID conflicts with existing RubyMine/Puma setups.

## Problem
- RubyMine/Puma uses default PID file: `/tmp/pids/server.pid`
- Multiple servers can't use the same PID file
- Results in "A server is already running" error

## Solution for Future Testing

### Option 1: Use Different PID File
```bash
rails server -p 3001 --pid tmp/pids/server_test.pid
```

### Option 2: Use Different Port and PID
```bash
rails server -p 3002 --pid tmp/pids/server_test.pid
```

### Option 3: Background Server with Custom PID
```bash
rails server -p 3001 --pid tmp/pids/server_test.pid -d
```

## Current Setup
- **User's Server**: RubyMine/Puma on port 3001
- **Testing URLs**: Updated to use `http://localhost:3001`
- **PID File**: User manages their own PID file

## Best Practice
Always check for existing servers and use unique PID files:
```bash
# Check if server is running
ps aux | grep puma

# Kill existing server if needed
kill -9 <PID>

# Start with custom PID file
rails server -p 3001 --pid tmp/pids/server_test.pid
```

## Updated Testing URLs
- Players: `http://localhost:3001/players`
- Clubs: `http://localhost:3001/clubs`
- Locations: `http://localhost:3001/locations` 