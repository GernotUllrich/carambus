#!/bin/bash

# Carambus Mode Parameters Manager
# This script helps manage the complex parameter strings for different deployment modes

MODE_PARAMS_FILE="$HOME/.carambus_mode_params"

# Default parameters for different environments
# Using simple variables instead of associative arrays for better compatibility

# Local Server on Hetzner carambus.de server
DEFAULT_LOCAL_HETZNER="2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_production,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh"

# API Server on Hetzner carambus.de server  
DEFAULT_API_HETZNER="2025/2026,carambus_api,,,carambus_api,carambus_api_production,api.carambus.de,,,production,newapi.carambus.de,3001,master,manage-puma-api.sh"

# Local development
DEFAULT_LOCAL_DEV="2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_development,carambus.de,1,357,development,localhost,3000,master,manage-puma.sh"

# API development
DEFAULT_API_DEV="2025/2026,carambus_api,,,carambus_api,carambus_api_development,api.carambus.de,,,development,localhost,3001,master,manage-puma-api.sh"

# Function to save parameters
save_params() {
    local mode=$1
    local params=$2
    echo "$mode=$params" >> "$MODE_PARAMS_FILE"
    echo "✓ Saved parameters for mode: $mode"
}

# Function to load parameters
load_params() {
    local mode=$1
    if [ -f "$MODE_PARAMS_FILE" ]; then
        grep "^$mode=" "$MODE_PARAMS_FILE" | cut -d'=' -f2-
    fi
}

# Function to list available modes
list_modes() {
    echo "Available default modes:"
    echo "  local_hetzner"
    echo "  api_hetzner"
    echo "  local_dev"
    echo "  api_dev"
    
    if [ -f "$MODE_PARAMS_FILE" ]; then
        echo ""
        echo "Custom saved modes:"
        while IFS='=' read -r mode params; do
            if [[ $mode != "" ]]; then
                echo "  $mode"
            fi
        done < "$MODE_PARAMS_FILE"
    fi
}

# Function to show parameters for a mode
show_params() {
    local mode=$1
    local params
    
    # Check custom saved parameters first
    params=$(load_params "$mode")
    
    # If not found, check default parameters
    if [ -z "$params" ]; then
        case "$mode" in
            "local_hetzner")
                params="$DEFAULT_LOCAL_HETZNER"
                ;;
            "api_hetzner")
                params="$DEFAULT_API_HETZNER"
                ;;
            "local_dev")
                params="$DEFAULT_LOCAL_DEV"
                ;;
            "api_dev")
                params="$DEFAULT_API_DEV"
                ;;
        esac
    fi
    
    if [ -n "$params" ]; then
        echo "Parameters for mode '$mode':"
        echo "$params"
    else
        echo "❌ Mode '$mode' not found"
        echo "Use 'list' to see available modes"
    fi
}

# Function to execute mode command
execute_mode() {
    local mode=$1
    local params
    
    # Check custom saved parameters first
    params=$(load_params "$mode")
    
    # If not found, check default parameters
    if [ -z "$params" ]; then
        case "$mode" in
            "local_hetzner")
                params="$DEFAULT_LOCAL_HETZNER"
                ;;
            "api_hetzner")
                params="$DEFAULT_API_HETZNER"
                ;;
            "local_dev")
                params="$DEFAULT_LOCAL_DEV"
                ;;
            "api_dev")
                params="$DEFAULT_API_DEV"
                ;;
        esac
    fi
    
    if [ -n "$params" ]; then
        echo "Executing mode: $mode"
        echo "Parameters: $params"
        echo ""
        
        # Convert comma-separated string to space-separated arguments
        IFS=',' read -ra ARGS <<< "$params"
        
        # Execute the appropriate rake task
        if [[ $mode == *"local"* ]]; then
            bundle exec rails "mode:local[${ARGS[*]}]"
        elif [[ $mode == *"api"* ]]; then
            bundle exec rails "mode:api[${ARGS[*]}]"
        else
            echo "❌ Unknown mode type: $mode"
            exit 1
        fi
    else
        echo "❌ Mode '$mode' not found"
        echo "Use 'list' to see available modes"
        exit 1
    fi
}

# Main script logic
case "$1" in
    "list")
        list_modes
        ;;
    "show")
        if [ -z "$2" ]; then
            echo "Usage: $0 show <mode>"
            exit 1
        fi
        show_params "$2"
        ;;
    "save")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 save <mode> <parameters>"
            echo "Example: $0 save my_local '2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_production,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh'"
            exit 1
        fi
        save_params "$2" "$3"
        ;;
    "local"|"api")
        if [ -z "$2" ]; then
            echo "Usage: $0 <local|api> <mode>"
            echo "Example: $0 local local_hetzner"
            echo "Example: $0 api api_hetzner"
            echo ""
            echo "Available modes:"
            list_modes
            exit 1
        fi
        execute_mode "$2"
        ;;
    "status")
        bundle exec rails mode:status
        ;;
    "backup")
        bundle exec rails mode:backup
        ;;
    *)
        echo "Carambus Mode Parameters Manager"
        echo ""
        echo "Usage:"
        echo "  $0 list                    - List available modes"
        echo "  $0 show <mode>             - Show parameters for a mode"
        echo "  $0 save <mode> <params>    - Save custom parameters for a mode"
        echo "  $0 local <mode>            - Switch to LOCAL mode using saved/default parameters"
        echo "  $0 api <mode>              - Switch to API mode using saved/default parameters"
        echo "  $0 status                  - Show current mode status"
        echo "  $0 backup                  - Create backup of current configuration"
        echo ""
        echo "Examples:"
        echo "  $0 local local_hetzner     - Switch to LOCAL mode for Hetzner server"
        echo "  $0 api api_hetzner          - Switch to API mode for Hetzner server"
        echo "  $0 show local_hetzner       - Show parameters for local_hetzner mode"
        echo ""
        echo "Parameter format:"
        echo "  season_name,app_name,context,api_url,basename,database,domain,location_id,club_id,rails_env,host,port,branch,puma_script"
        echo ""
        echo "Default modes available:"
        list_modes
        ;;
esac
