#!/bin/bash

# Version Cleanup Script for Carambus
# This script provides easy access to version cleanup tasks

set -e

echo "Carambus Version Cleanup Script"
echo "==============================="
echo ""

# Check if we're in the right directory
if [ ! -f "config/application.rb" ]; then
    echo "Error: Please run this script from the Rails application root directory"
    exit 1
fi

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  fast     - Use SQL-based cleanup (FASTEST - recommended for large datasets)"
    echo "  safe     - Use Ruby-based cleanup (SAFER - processes records individually)"
    echo "  stats    - Show statistics about version region data"
    echo "  verify   - Verify that all versions have correct region data"
    echo "  model    - Update versions for a specific model (requires model name)"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 fast                    # Fast SQL-based cleanup"
    echo "  $0 safe                    # Safe Ruby-based cleanup"
    echo "  $0 stats                   # Show statistics"
    echo "  $0 verify                  # Verify data integrity"
    echo "  $0 model Tournament        # Update versions for Tournament model only"
    echo ""
}

# Function to run the cleanup
run_cleanup() {
    local method=$1
    local model_name=$2
    
    echo "Starting version cleanup..."
    echo "Method: $method"
    if [ -n "$model_name" ]; then
        echo "Model: $model_name"
    fi
    echo ""
    
    case $method in
        "fast")
            echo "Running SQL-based cleanup (FASTEST)..."
            bundle exec rails version_cleanup:update_region_data_sql
            ;;
        "safe")
            echo "Running Ruby-based cleanup (SAFER)..."
            bundle exec rails version_cleanup:update_region_data
            ;;
        "stats")
            echo "Showing version statistics..."
            bundle exec rails version_cleanup:stats
            ;;
        "verify")
            echo "Verifying version data..."
            bundle exec rails version_cleanup:verify
            ;;
        "model")
            if [ -z "$model_name" ]; then
                echo "Error: Model name is required for 'model' option"
                echo "Usage: $0 model ModelName"
                exit 1
            fi
            echo "Updating versions for model: $model_name"
            bundle exec rails "version_cleanup:update_model[$model_name]"
            ;;
        *)
            echo "Error: Unknown method '$method'"
            show_usage
            exit 1
            ;;
    esac
}

# Main script logic
case "${1:-help}" in
    "fast"|"safe"|"stats"|"verify")
        run_cleanup "$1"
        ;;
    "model")
        if [ -z "$2" ]; then
            echo "Error: Model name is required for 'model' option"
            echo "Usage: $0 model ModelName"
            exit 1
        fi
        run_cleanup "model" "$2"
        ;;
    "help"|"-h"|"--help"|"")
        show_usage
        ;;
    *)
        echo "Error: Unknown option '$1'"
        show_usage
        exit 1
        ;;
esac

echo ""
echo "Cleanup completed!" 