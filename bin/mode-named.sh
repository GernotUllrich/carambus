#!/bin/bash

# Carambus Named Mode Parameters Manager
# This script provides a more robust way to manage deployment parameters using named parameters

MODE_PARAMS_FILE="$HOME/.carambus_named_mode_params"

# Function to show usage
show_usage() {
    echo "Carambus Named Mode Parameters Manager"
    echo ""
    echo "Usage:"
    echo "  $0 local [options]     - Switch to LOCAL mode with named parameters"
    echo "  $0 api [options]       - Switch to API mode with named parameters"
    echo "  $0 status [detailed]  - Show current status"
    echo "  $0 save <name> [options] - Save current parameters as a named configuration"
    echo "  $0 load <name>         - Load a saved configuration"
    echo "  $0 list               - List saved configurations"
    echo ""
    echo "Options:"
    echo "  --season-name=VALUE     - Season identifier (e.g., '2025/2026')"
    echo "  --application-name=VALUE - Application name (e.g., 'carambus', 'carambus_api')"
    echo "  --context=VALUE         - Context identifier (e.g., 'NBV', '')"
    echo "  --api-url=VALUE         - API URL for LOCAL mode"
    echo "  --basename=VALUE        - Deploy basename (e.g., 'carambus', 'carambus_api')"
    echo "  --database=VALUE        - Database name"
    echo "  --domain=VALUE          - Domain name"
    echo "  --location-id=VALUE     - Location ID"
    echo "  --club-id=VALUE         - Club ID"
    echo "  --rails-env=VALUE       - Rails environment"
    echo "  --host=VALUE            - Server hostname"
    echo "  --port=VALUE            - Server port"
    echo "  --branch=VALUE          - Git branch"
    echo "  --puma-script=VALUE     - Puma management script"
    echo ""
    echo "Examples:"
    echo "  $0 api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001"
    echo "  $0 local --season-name='2025/2026' --context=NBV --api-url='https://newapi.carambus.de/'"
    echo "  $0 save my_config --basename=carambus_api --database=carambus_api_production"
    echo "  $0 load my_config"
}

# Function to parse named parameters
parse_named_params() {
    local params=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --*=*)
                # Convert --key=value to key=value format
                local param="${1#--}"
                params="${params}${param},"
                shift
                ;;
            --*)
                # Handle --key value format
                local key="${1#--}"
                shift
                if [[ $# -gt 0 ]]; then
                    params="${params}${key}=$1,"
                    shift
                fi
                ;;
            *)
                # Unknown option
                echo "❌ Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    echo "${params%,}"  # Remove trailing comma
}

# Function to save configuration
save_config() {
    local name=$1
    shift
    local params=$(parse_named_params "$@")
    
    if [[ -n "$params" ]]; then
        echo "$name=$params" > "$MODE_PARAMS_FILE.$name"
        echo "✅ Saved configuration '$name' with parameters:"
        echo "$params"
    else
        echo "❌ No parameters provided for configuration '$name'"
        exit 1
    fi
}

# Function to load configuration
load_config() {
    local name=$1
    local config_file="$MODE_PARAMS_FILE.$name"
    
    if [[ -f "$config_file" ]]; then
        local params=$(cat "$config_file" | cut -d'=' -f2-)
        echo "✅ Loaded configuration '$name':"
        echo "$params"
    else
        echo "❌ Configuration '$name' not found"
        exit 1
    fi
}

# Function to list configurations
list_configs() {
    echo "📋 Saved configurations:"
    if [[ -d "$(dirname "$MODE_PARAMS_FILE")" ]]; then
        for file in "$MODE_PARAMS_FILE".*; do
            if [[ -f "$file" ]]; then
                local name=$(basename "$file" | sed "s/$(basename "$MODE_PARAMS_FILE")\.//")
                local params=$(cat "$file" | cut -d'=' -f2-)
                echo "  $name: $params"
            fi
        done
    fi
}

# Function to execute mode with parameters
execute_mode() {
    local mode=$1
    shift
    local params=$(parse_named_params "$@")
    
    if [[ -n "$params" ]]; then
        echo "🚀 Executing $mode mode with parameters:"
        echo "$params"
        echo ""
        
        # Set environment variable for Rake task
        export MODE_PARAMS="$params"
        
        # Execute the appropriate Rake task
        if [[ "$mode" == "local" ]]; then
            bundle exec rails "mode:local_named"
        elif [[ "$mode" == "api" ]]; then
            bundle exec rails "mode:api_named"
        else
            echo "❌ Unknown mode: $mode"
            exit 1
        fi
    else
        echo "❌ No parameters provided for $mode mode"
        exit 1
    fi
}

# Main script logic
case "$1" in
    "local")
        shift
        execute_mode "local" "$@"
        ;;
    "api")
        shift
        execute_mode "api" "$@"
        ;;
    "save")
        shift
        if [[ $# -gt 0 ]]; then
            save_config "$@"
        else
            echo "❌ Configuration name required"
            show_usage
            exit 1
        fi
        ;;
    "load")
        shift
        if [[ $# -gt 0 ]]; then
            load_config "$@"
        else
            echo "❌ Configuration name required"
            show_usage
            exit 1
        fi
        ;;
    "list")
        list_configs
        ;;
    "status")
        shift
        if [[ "$1" == "detailed" ]]; then
            bundle exec rails "mode:status[detailed]"
        else
            bundle exec rails "mode:status"
        fi
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_usage
        exit 1
        ;;
esac
