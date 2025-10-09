#!/bin/bash
# cleanup_rails.sh - Clean up stale Rails processes and PID files

echo "Cleaning up stale Rails processes..."

# Kill any existing Rails processes
pkill -f "rails s" 2>/dev/null || true
pkill -f "puma" 2>/dev/null || true

# Remove stale PID files
rm -f tmp/pids/server.pid
rm -f tmp/pids/puma.pid

# Wait a moment for processes to die
sleep 2

echo "Cleanup complete. You can now start Rails with: rails s"
