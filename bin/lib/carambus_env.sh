#!/bin/bash
# Carambus Environment Setup
# Source this file in all scripts: source "$(dirname "$0")/lib/carambus_env.sh"
# or if script is already in bin: source "$(dirname "$0")/carambus_env.sh"

# Function to detect CARAMBUS_BASE
detect_carambus_base() {
    # 1. Check environment variable (highest priority)
    if [ -n "$CARAMBUS_BASE" ]; then
        echo "$CARAMBUS_BASE"
        return 0
    fi
    
    # 2. Check config file in home directory
    if [ -f "$HOME/.carambus_config" ]; then
        local config_base=$(grep "^CARAMBUS_BASE=" "$HOME/.carambus_config" | cut -d'=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$config_base" ]; then
            echo "$config_base"
            return 0
        fi
    fi
    
    # 3. Auto-detect based on script location
    # Assume script is in $CARAMBUS_BASE/carambus_*/bin/ or $CARAMBUS_BASE/carambus_*/bin/lib/
    local script_path="${BASH_SOURCE[0]}"
    
    # If this file is sourced, use the caller's location
    if [ "${BASH_SOURCE[1]}" ]; then
        script_path="${BASH_SOURCE[1]}"
    fi
    
    local script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    
    # Go up until we find carambus_data directory (sibling indicator)
    local current="$script_dir"
    local max_depth=5
    local depth=0
    
    while [ "$current" != "/" ] && [ $depth -lt $max_depth ]; do
        # Check if parent has carambus_data
        local parent="$(dirname "$current")"
        if [ -d "$parent/carambus_data" ]; then
            echo "$parent"
            return 0
        fi
        current="$parent"
        ((depth++))
    done
    
    # 4. Fallback default
    echo "/Volumes/EXT2TB/gullrich/DEV/carambus"
}

# Detect and export CARAMBUS_BASE
export CARAMBUS_BASE=$(detect_carambus_base)

# Derived paths
export CARAMBUS_DATA="$CARAMBUS_BASE/carambus_data"
export CARAMBUS_MASTER="$CARAMBUS_BASE/carambus_master"
export CARAMBUS_API="$CARAMBUS_BASE/carambus_api"
export CARAMBUS_BCW="$CARAMBUS_BASE/carambus_bcw"
export CARAMBUS_LOCATION_5101="$CARAMBUS_BASE/carambus_location_5101"

# Scenarios path
export SCENARIOS_PATH="$CARAMBUS_DATA/scenarios"

# Verbose output if CARAMBUS_DEBUG is set
if [ -n "$CARAMBUS_DEBUG" ]; then
    echo "[CARAMBUS_ENV] CARAMBUS_BASE: $CARAMBUS_BASE" >&2
    echo "[CARAMBUS_ENV] CARAMBUS_DATA: $CARAMBUS_DATA" >&2
    echo "[CARAMBUS_ENV] SCENARIOS_PATH: $SCENARIOS_PATH" >&2
fi

