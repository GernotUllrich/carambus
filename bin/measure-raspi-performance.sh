#!/bin/bash
# Raspberry Pi Performance Measurement Script
# Measures system performance before and after optimizations
# Usage: ./bin/measure-raspi-performance.sh <raspi_ip> [ssh_user] [ssh_port]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

# Parse arguments
MODE="before"
BEFORE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --after)
            MODE="after"
            shift
            ;;
        --before-file)
            BEFORE_FILE="$2"
            shift 2
            ;;
        -*)
            error "Unknown option: $1"
            echo "Usage: $0 <raspi_ip> [ssh_user] [ssh_port] [--after] [--before-file <file>]"
            exit 1
            ;;
        *)
            if [ -z "$RASPI_IP" ]; then
                RASPI_IP="$1"
            elif [ -z "$SSH_USER" ]; then
                SSH_USER="$1"
            elif [ -z "$SSH_PORT" ]; then
                SSH_PORT="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$RASPI_IP" ]; then
    error "Usage: $0 <raspi_ip> [ssh_user] [ssh_port] [--after] [--before-file <file>]"
    echo ""
    echo "Examples:"
    echo "  # BEFORE measurement:"
    echo "  $0 192.168.178.176 pi 22"
    echo ""
    echo "  # AFTER measurement (with comparison):"
    echo "  $0 192.168.178.176 pi 22 --after --before-file raspi_performance_results/before_192.168.178.176_20250101_120000.txt"
    exit 1
fi

SSH_USER="${SSH_USER:-pi}"
SSH_PORT="${SSH_PORT:-22}"

if [ "$MODE" = "after" ] && [ -z "$BEFORE_FILE" ]; then
    error "ERROR: --after mode requires --before-file"
    echo "Please specify the BEFORE measurement file:"
    echo "  $0 $RASPI_IP $SSH_USER $SSH_PORT --after --before-file <before_file>"
    exit 1
fi

if [ "$MODE" = "after" ] && [ ! -f "$BEFORE_FILE" ]; then
    error "ERROR: BEFORE file not found: $BEFORE_FILE"
    exit 1
fi

# Test SSH connection
info "Testing SSH connection to $SSH_USER@$RASPI_IP:$SSH_PORT..."
if ! ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$RASPI_IP" "echo 'SSH OK'" 2>/dev/null; then
    error "SSH connection failed"
    exit 1
fi
log "✅ SSH connection successful"
echo ""

# Function to run measurement
run_measurement() {
    local label="$1"
    local output_file="$2"
    
    log "📊 Running measurement: $label"
    log "=================================="
    
    # System info
    info "System Information:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== System Info ==='
        cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown model'
        uname -m
        cat /proc/cpuinfo | grep '^Model name' | head -1 || cat /proc/cpuinfo | grep '^model name' | head -1 || echo 'CPU: Unknown'
        echo ''
    " >> "$output_file"
    
    # Memory usage
    info "Memory Usage:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Memory Usage ==='
        free -h
        echo ''
        echo '=== Memory Details ==='
        free -m | awk '/^Mem:/ {printf \"Total: %dMB, Used: %dMB, Free: %dMB, Available: %dMB, Usage: %.1f%%\n\", \$2, \$3, \$4, \$7, (\$3/\$2)*100}'
        echo ''
    " >> "$output_file"
    
    # Swap usage
    info "Swap Usage:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Swap Usage ==='
        free -m | awk '/^Swap:/ {printf \"Total: %dMB, Used: %dMB, Free: %dMB, Usage: %.1f%%\n\", \$2, \$3, \$4, (\$2>0 ? (\$3/\$2)*100 : 0)}'
        echo ''
    " >> "$output_file"
    
    # CPU usage (1 second average)
    info "CPU Usage:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== CPU Usage ==='
        top -bn1 | grep '^%Cpu' || top -bn1 | grep '^Cpu(s)'
        echo ''
    " >> "$output_file"
    
    # Load average
    info "Load Average:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Load Average ==='
        uptime
        echo ''
    " >> "$output_file"
    
    # Running processes (top 10 by memory)
    info "Top Memory Consumers:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Top 10 Processes by Memory ==='
        ps aux --sort=-%mem | head -11
        echo ''
    " >> "$output_file"
    
    # NetworkManager connections
    info "Network Connections:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Active Network Connections ==='
        nmcli connection show --active 2>/dev/null || echo 'NetworkManager not available'
        echo ''
        echo '=== All Network Connections ==='
        nmcli connection show 2>/dev/null | head -20 || echo 'NetworkManager not available'
        echo ''
    " >> "$output_file"
    
    # Systemd services status
    info "System Services:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Enabled Services (memory-related) ==='
        systemctl list-unit-files --type=service --state=enabled | grep -E '(bluetooth|avahi|cups|chromium|scoreboard)' || echo 'No matching services'
        echo ''
    " >> "$output_file"
    
    # Disk I/O (if iostat available)
    info "Disk I/O:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Disk I/O ==='
        if command -v iostat >/dev/null 2>&1; then
            iostat -x 1 2 | tail -5
        else
            echo 'iostat not available'
        fi
        echo ''
    " >> "$output_file"
    
    # Chromium process (if running)
    info "Chromium Process:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Chromium Process ==='
        if pgrep -x chromium >/dev/null 2>&1 || pgrep -x chromium-browser >/dev/null 2>&1; then
            ps aux | grep -E '(chromium|chromium-browser)' | grep -v grep | head -5
            echo ''
            echo '=== Chromium Memory Usage ==='
            CHROMIUM_PID=\$(pgrep -x chromium 2>/dev/null || pgrep -x chromium-browser 2>/dev/null)
            if [ -n \"\$CHROMIUM_PID\" ]; then
                ps -o pid,rss,vsz,comm -p \$CHROMIUM_PID 2>/dev/null || echo 'Cannot get Chromium memory'
                echo ''
                echo '=== Chromium Memory Details ==='
                ps -p \$CHROMIUM_PID -o rss= | awk '{printf \"RSS: %dMB\n\", \$1/1024}'
            fi
        else
            echo 'Chromium not running'
        fi
        echo ''
    " >> "$output_file"
    
    # Browser performance test (if Chromium is running and scoreboard URL is accessible)
    info "Browser Performance Test:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== Browser Performance Test ==='
        if pgrep -x chromium >/dev/null 2>&1 || pgrep -x chromium-browser >/dev/null 2>&1; then
            echo 'Chromium is running - performance test available'
            echo 'Note: For detailed browser metrics, check Chromium DevTools'
            echo '      or use: chrome://system/ in browser'
        else
            echo 'Chromium not running - cannot test browser performance'
        fi
        echo ''
    " >> "$output_file"
    
    # Temperature (if available)
    info "System Temperature:"
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo '=== CPU Temperature ==='
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            TEMP=\$(cat /sys/class/thermal/thermal_zone0/temp)
            echo \"Temperature: \$((TEMP/1000))°C\"
        else
            echo 'Temperature sensor not available'
        fi
        echo ''
    " >> "$output_file"
    
    log "✅ Measurement complete: $label"
    echo ""
}

# Function to extract numeric values from measurement files
extract_value() {
    local file="$1"
    local pattern="$2"
    grep "$pattern" "$file" | awk '{print $NF}' | tr -d '%' | head -1
}

# Function to compare measurements
compare_measurements() {
    local before_file="$1"
    local after_file="$2"
    local comparison_file="$3"
    
    log "📊 Comparing Measurements"
    log "=========================="
    
    # Extract key metrics (with fallbacks)
    BEFORE_MEM_USED=$(grep "Memory Details" "$before_file" -A 1 | grep -oE "Used: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    BEFORE_MEM_AVAIL=$(grep "Memory Details" "$before_file" -A 1 | grep -oE "Available: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    BEFORE_MEM_PERCENT=$(grep "Memory Details" "$before_file" -A 1 | grep -oE "Usage: [0-9.]+" | awk '{print $2}' | head -1 || echo "0")
    BEFORE_SWAP_USED=$(grep "Swap Usage" "$before_file" -A 1 | grep -oE "Used: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    BEFORE_SWAP_PERCENT=$(grep "Swap Usage" "$before_file" -A 1 | grep -oE "Usage: [0-9.]+" | awk '{print $2}' | head -1 || echo "0")
    
    AFTER_MEM_USED=$(grep "Memory Details" "$after_file" -A 1 | grep -oE "Used: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    AFTER_MEM_AVAIL=$(grep "Memory Details" "$after_file" -A 1 | grep -oE "Available: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    AFTER_MEM_PERCENT=$(grep "Memory Details" "$after_file" -A 1 | grep -oE "Usage: [0-9.]+" | awk '{print $2}' | head -1 || echo "0")
    AFTER_SWAP_USED=$(grep "Swap Usage" "$after_file" -A 1 | grep -oE "Used: [0-9]+" | awk '{print $2}' | head -1 || echo "0")
    AFTER_SWAP_PERCENT=$(grep "Swap Usage" "$after_file" -A 1 | grep -oE "Usage: [0-9.]+" | awk '{print $2}' | head -1 || echo "0")
    
    # Calculate improvements
    MEM_IMPROVEMENT=$((BEFORE_MEM_USED - AFTER_MEM_USED))
    MEM_AVAIL_IMPROVEMENT=$((AFTER_MEM_AVAIL - BEFORE_MEM_AVAIL))
    MEM_PERCENT_IMPROVEMENT=$(echo "$BEFORE_MEM_PERCENT - $AFTER_MEM_PERCENT" | bc 2>/dev/null || echo "0")
    SWAP_IMPROVEMENT=$((BEFORE_SWAP_USED - AFTER_SWAP_USED))
    
    # Generate comparison report
    {
        echo "=========================================="
        echo "PERFORMANCE COMPARISON REPORT"
        echo "=========================================="
        echo ""
        echo "BEFORE File: $before_file"
        echo "AFTER File: $after_file"
        echo "Generated: $(date)"
        echo ""
        echo "=========================================="
        echo "MEMORY USAGE"
        echo "=========================================="
        printf "%-30s %15s %15s %15s\n" "Metric" "BEFORE" "AFTER" "Change"
        echo "------------------------------------------"
        printf "%-30s %15s %15s %15s\n" "Memory Used (MB)" "${BEFORE_MEM_USED}MB" "${AFTER_MEM_USED}MB" "${MEM_IMPROVEMENT:+$MEM_IMPROVEMENT}MB"
        printf "%-30s %15s %15s %15s\n" "Memory Available (MB)" "${BEFORE_MEM_AVAIL}MB" "${AFTER_MEM_AVAIL}MB" "${MEM_AVAIL_IMPROVEMENT:+$MEM_AVAIL_IMPROVEMENT}MB"
        printf "%-30s %15s %15s %15s\n" "Memory Usage (%)" "${BEFORE_MEM_PERCENT}%" "${AFTER_MEM_PERCENT}%" "${MEM_PERCENT_IMPROVEMENT:+$MEM_PERCENT_IMPROVEMENT}%"
        echo ""
        echo "=========================================="
        echo "SWAP USAGE"
        echo "=========================================="
        printf "%-30s %15s %15s %15s\n" "Metric" "BEFORE" "AFTER" "Change"
        echo "------------------------------------------"
        printf "%-30s %15s %15s %15s\n" "Swap Used (MB)" "${BEFORE_SWAP_USED}MB" "${AFTER_SWAP_USED}MB" "${SWAP_IMPROVEMENT:+$SWAP_IMPROVEMENT}MB"
        printf "%-30s %15s %15s %15s\n" "Swap Usage (%)" "${BEFORE_SWAP_PERCENT}%" "${AFTER_SWAP_PERCENT}%" "$(echo "$BEFORE_SWAP_PERCENT - $AFTER_SWAP_PERCENT" | bc 2>/dev/null || echo "0")%"
        echo ""
        echo "=========================================="
        echo "SUMMARY"
        echo "=========================================="
        if [ "$MEM_IMPROVEMENT" -gt 0 ]; then
            echo "✅ Memory usage reduced by ${MEM_IMPROVEMENT}MB (${MEM_PERCENT_IMPROVEMENT}%)"
        elif [ "$MEM_IMPROVEMENT" -lt 0 ]; then
            echo "⚠️  Memory usage increased by $((MEM_IMPROVEMENT * -1))MB"
        else
            echo "➡️  Memory usage unchanged"
        fi
        
        if [ "$MEM_AVAIL_IMPROVEMENT" -gt 0 ]; then
            echo "✅ Available memory increased by ${MEM_AVAIL_IMPROVEMENT}MB"
        elif [ "$MEM_AVAIL_IMPROVEMENT" -lt 0 ]; then
            echo "⚠️  Available memory decreased by $((MEM_AVAIL_IMPROVEMENT * -1))MB"
        else
            echo "➡️  Available memory unchanged"
        fi
        
        if [ "$SWAP_IMPROVEMENT" -gt 0 ]; then
            echo "✅ Swap usage reduced by ${SWAP_IMPROVEMENT}MB"
        elif [ "$SWAP_IMPROVEMENT" -lt 0 ]; then
            echo "⚠️  Swap usage increased by $((SWAP_IMPROVEMENT * -1))MB"
        else
            echo "➡️  Swap usage unchanged"
        fi
        echo ""
    } > "$comparison_file"
    
    # Display comparison
    cat "$comparison_file"
    log "✅ Comparison report saved to: $comparison_file"
}

# Create results directory
RESULTS_DIR="raspi_performance_results"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ "$MODE" = "before" ]; then
    BEFORE_FILE="$RESULTS_DIR/before_${RASPI_IP}_${TIMESTAMP}.txt"
    
    log "🔍 Raspberry Pi Performance Measurement - BEFORE"
    log "================================================="
    log "Target: $SSH_USER@$RASPI_IP:$SSH_PORT"
    log "Results will be saved to: $RESULTS_DIR/"
    echo ""
    
    # Run BEFORE measurement
    run_measurement "BEFORE Optimizations" "$BEFORE_FILE"
    
    # Show summary
    info "📋 BEFORE Summary:"
    echo "=================="
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo 'Memory:'
        free -m | awk '/^Mem:/ {printf \"  Total: %dMB, Used: %dMB (%.1f%%), Available: %dMB\n\", \$2, \$3, (\$3/\$2)*100, \$7}'
        echo ''
        echo 'Swap:'
        free -m | awk '/^Swap:/ {printf \"  Total: %dMB, Used: %dMB (%.1f%%)\n\", \$2, \$3, (\$2>0 ? (\$3/\$2)*100 : 0)}'
        echo ''
        echo 'Load Average:'
        uptime | awk -F'load average:' '{print \"  \" \$2}'
        echo ''
        echo 'Top Memory Process:'
        ps aux --sort=-%mem | head -2 | tail -1 | awk '{printf \"  %s: %sMB (%.1f%%)\n\", \$11, \$6/1024, \$4}'
    "
    echo ""
    
    warning "⚠️  Now apply your optimizations (disable services, remove packages, etc.)"
    warning "   Then run this script again with '--after' flag to measure improvements"
    warning ""
    info "To run AFTER measurement:"
    echo "  $0 $RASPI_IP $SSH_USER $SSH_PORT --after --before-file '$BEFORE_FILE'"
    echo ""
    
    log "✅ BEFORE measurement saved to: $BEFORE_FILE"
    
else
    # AFTER mode
    AFTER_FILE="$RESULTS_DIR/after_${RASPI_IP}_${TIMESTAMP}.txt"
    COMPARISON_FILE="$RESULTS_DIR/comparison_${RASPI_IP}_${TIMESTAMP}.txt"
    
    log "🔍 Raspberry Pi Performance Measurement - AFTER"
    log "================================================"
    log "Target: $SSH_USER@$RASPI_IP:$SSH_PORT"
    log "Comparing with: $BEFORE_FILE"
    echo ""
    
    # Run AFTER measurement
    run_measurement "AFTER Optimizations" "$AFTER_FILE"
    
    # Show summary
    info "📋 AFTER Summary:"
    echo "================="
    ssh -p "$SSH_PORT" "$SSH_USER@$RASPI_IP" "
        echo 'Memory:'
        free -m | awk '/^Mem:/ {printf \"  Total: %dMB, Used: %dMB (%.1f%%), Available: %dMB\n\", \$2, \$3, (\$3/\$2)*100, \$7}'
        echo ''
        echo 'Swap:'
        free -m | awk '/^Swap:/ {printf \"  Total: %dMB, Used: %dMB (%.1f%%)\n\", \$2, \$3, (\$2>0 ? (\$3/\$2)*100 : 0)}'
        echo ''
        echo 'Load Average:'
        uptime | awk -F'load average:' '{print \"  \" \$2}'
        echo ''
        echo 'Top Memory Process:'
        ps aux --sort=-%mem | head -2 | tail -1 | awk '{printf \"  %s: %sMB (%.1f%%)\n\", \$11, \$6/1024, \$4}'
    "
    echo ""
    
    # Compare measurements
    compare_measurements "$BEFORE_FILE" "$AFTER_FILE" "$COMPARISON_FILE"
    
    log "✅ AFTER measurement saved to: $AFTER_FILE"
fi

