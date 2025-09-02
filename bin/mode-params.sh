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
            # Join array elements with commas for rake task arguments
            rake_args=$(IFS=','; echo "${ARGS[*]}")
            bundle exec rails "mode:local[${rake_args}]"
        elif [[ $mode == *"api"* ]]; then
            # Join array elements with commas for rake task arguments
            rake_args=$(IFS=','; echo "${ARGS[*]}")
            bundle exec rails "mode:api[${rake_args}]"
        else
            echo "❌ Unknown type: $mode"
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
        if [ "$2" = "detailed" ] || [ "$2" = "detail" ] || [ "$2" = "-d" ] || [ "$2" = "--detailed" ]; then
            bundle exec rails "mode:status[detailed]"
        else
            bundle exec rails mode:status
        fi
        ;;
    "pre_deploy")
        if [ "$2" = "detailed" ] || [ "$2" = "detail" ] || [ "$2" = "-d" ] || [ "$2" = "--detailed" ]; then
            bundle exec rails "mode:pre_deploy_status[detailed]"
        else
            bundle exec rails mode:pre_deploy_status
        fi
        ;;
    "post_deploy")
        if [ "$2" = "detailed" ] || [ "$2" = "detail" ] || [ "$2" = "-d" ] || [ "$2" = "--detailed" ]; then
            bundle exec rails "mode:post_deploy_status[detailed]"
        else
            bundle exec rails mode:post_deploy_status
        fi
        ;;
    "backup")
        bundle exec rails mode:backup
        ;;
    "db_dump")
        if [ -z "$2" ]; then
            bundle exec rails "mode:prepare_db_dump"
        else
            bundle exec rails "mode:prepare_db_dump[$2]"
        fi
        ;;
    "list_dumps")
        bundle exec rails mode:list_db_dumps
        ;;
    "validate")
        bundle exec rails mode:validate_deployment
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
        echo "  $0 status detailed         - Show detailed parameter breakdown"
        echo "  $0 pre_deploy              - Show local deployment configuration (pre-deployment validation)"
        echo "  $0 pre_deploy detailed     - Show detailed local deployment configuration"
        echo "  $0 post_deploy             - Show production deployment configuration (post-deployment verification)"
        echo "  $0 post_deploy detailed    - Show detailed production deployment configuration"
        echo "  $0 backup                  - Create backup of current configuration"
        echo "  $0 db_dump [database]      - Create database dump for deployment"
        echo "  $0 list_dumps              - List available database dumps"
        echo "  $0 validate                - Validate production configuration before deployment"
        echo ""
        echo "Examples:"
        echo "  $0 local local_hetzner     - Switch to LOCAL mode for Hetzner server"
        echo "  $0 api api_hetzner          - Switch to API mode for Hetzner server"
        echo "  $0 show local_hetzner       - Show parameters for local_hetzner mode"
        echo "  $0 status detailed          - Show detailed parameter breakdown"
        echo "  $0 pre_deploy detailed      - Validate configuration before deployment"
        echo "  $0 post_deploy detailed     - Verify configuration after deployment"
        echo "  $0 db_dump carambus_production - Create database dump"
        echo "  $0 list_dumps               - List available dumps"
        echo ""
        echo "Parameter format:"
        echo "  season_name,app_name,context,api_url,basename,database,domain,location_id,club_id,rails_env,host,port,branch,puma_script"
        echo ""
        echo "Default modes available:"
        list_modes
        ;;
esac
