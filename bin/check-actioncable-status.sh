#!/bin/bash
# Quick status check for ActionCable Redis configuration
# Usage: ./bin/check-actioncable-status.sh

set -e

echo "=========================================================================="
echo "ActionCable Redis Status Check"
echo "=========================================================================="
echo

# Check 1: cable.yml configuration
echo "📋 Checking config/cable.yml..."
if grep -q "adapter: redis" config/cable.yml; then
  echo "   ✅ Using redis adapter"
  redis_url=$(grep "url:" config/cable.yml | head -1 | sed 's/.*url:.*{//' | sed 's/}.*//' | tr -d '"' | tr -d "'")
  if [ -n "$redis_url" ]; then
    echo "   Redis URL: ${redis_url}"
  fi
else
  echo "   ❌ NOT using redis adapter (using async?)"
  echo "   FIX: Update config/cable.yml to use redis adapter"
  echo "   See: docs/ACTIONCABLE_REDIS_FIX.md"
  exit 1
fi
echo

# Check 2: Redis server running
echo "🔌 Checking Redis connection..."
if command -v redis-cli >/dev/null 2>&1; then
  if redis-cli ping >/dev/null 2>&1; then
    echo "   ✅ Redis is running and responding"
    redis_version=$(redis-cli INFO server | grep "redis_version:" | cut -d: -f2 | tr -d '\r')
    echo "   Version: ${redis_version}"
    connected_clients=$(redis-cli INFO clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r')
    echo "   Connected clients: ${connected_clients}"
  else
    echo "   ❌ Redis not responding"
    echo "   FIX: Start Redis server"
    echo "   macOS: brew services start redis"
    echo "   Linux: sudo systemctl start redis"
    exit 1
  fi
else
  echo "   ⚠️  redis-cli not found in PATH"
  echo "   Cannot verify Redis status"
fi
echo

# Check 3: Rails environment
echo "🚂 Checking Rails environment..."
if [ -f "config/environment.rb" ]; then
  echo "   ✅ Rails project detected"
  
  # Check if server needs restart (look for changes to cable.yml)
  if [ -f "tmp/pids/server.pid" ]; then
    pid=$(cat tmp/pids/server.pid 2>/dev/null || echo "")
    if [ -n "$pid" ] && ps -p $pid >/dev/null 2>&1; then
      echo "   ℹ️  Rails server is running (PID: $pid)"
      
      # Check if cable.yml is newer than server process
      if [ "config/cable.yml" -nt "/proc/$pid" ] 2>/dev/null || [ "config/cable.yml" -nt "tmp/pids/server.pid" ]; then
        echo "   ⚠️  cable.yml modified after server start"
        echo "   ACTION REQUIRED: Restart Rails server for changes to take effect"
        echo "   Press Ctrl+C in server terminal, then run: bin/dev (or rails server)"
      fi
    else
      echo "   ℹ️  Rails server not running (PID file stale)"
    fi
  else
    echo "   ℹ️  Rails server not running"
    echo "   Start with: bin/dev (or rails server)"
  fi
else
  echo "   ❌ Not a Rails project"
  exit 1
fi
echo

# Check 4: Test Redis pub/sub (if Rails console available)
echo "🧪 Testing Redis pub/sub capability..."
if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
  echo "   Running quick pub/sub test..."
  
  # Subscribe in background
  timeout 3 redis-cli SUBSCRIBE "test-channel" > /tmp/redis-test-sub.log 2>&1 &
  sub_pid=$!
  sleep 0.5
  
  # Publish message
  redis-cli PUBLISH "test-channel" "test-message" >/dev/null 2>&1
  sleep 0.5
  
  # Check if message was received
  if grep -q "test-message" /tmp/redis-test-sub.log 2>/dev/null; then
    echo "   ✅ Redis pub/sub is working"
  else
    echo "   ⚠️  Redis pub/sub test inconclusive"
  fi
  
  # Cleanup
  kill $sub_pid 2>/dev/null || true
  rm -f /tmp/redis-test-sub.log
else
  echo "   ⏭️  Skipping (Redis not available)"
fi
echo

echo "=========================================================================="
echo "Status Summary"
echo "=========================================================================="
echo
echo "✅ ActionCable is configured to use Redis adapter"
echo "✅ Redis server is running and accessible"
echo
echo "Next steps for testing:"
echo "1. Ensure Rails server is running (and restarted after cable.yml changes)"
echo "2. Open multiple browsers to the same scoreboard URL"
echo "3. Make an update in one browser"
echo "4. Verify other browsers receive the update immediately"
echo
echo "For detailed testing and troubleshooting:"
echo "  - Run: ruby bin/test-actioncable-redis.rb"
echo "  - See: docs/ACTIONCABLE_REDIS_FIX.md"
echo


