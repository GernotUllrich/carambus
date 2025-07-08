#!/bin/bash
# Scoreboard control script for www-data user
# This script allows www-data to control the pj user's systemd service

case "$1" in
    start)
        echo "Starting scoreboard..."
        ssh -p 8910 pj@192.168.178.48 "systemctl --user start scoreboard.service"
        ;;
    stop)
        echo "Stopping scoreboard..."
        ssh -p 8910 pj@192.168.178.48 "systemctl --user stop scoreboard.service"
        ;;
    restart)
        echo "Restarting scoreboard..."
        ssh -p 8910 pj@192.168.178.48 "systemctl --user restart scoreboard.service"
        ;;
    status)
        echo "Scoreboard status:"
        ssh -p 8910 pj@192.168.178.48 "systemctl --user status scoreboard.service"
        ;;
    logs)
        echo "Scoreboard logs:"
        cat /tmp/scoreboard-autostart.log 2>/dev/null || echo "No log file found"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the scoreboard"
        echo "  stop    - Stop the scoreboard"
        echo "  restart - Restart the scoreboard"
        echo "  status  - Show service status"
        echo "  logs    - Show logs"
        exit 1
        ;;
esac 