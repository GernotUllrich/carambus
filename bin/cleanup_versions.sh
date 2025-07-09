#!/bin/bash

# Version Cleanup Script for Carambus
# This script copies region_id and global_context from items to their versions

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
    echo "  fast     - Use SQL-based copy (FASTEST - recommended)"
    echo "  safe     - Use Ruby-based copy (SAFER - uses ActiveRecord)"
    echo "  stats    - Show statistics about version region data"
    echo "  verify   - Verify that all versions have correct region data"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 fast                    # Fast SQL-based copy"
    echo "  $0 safe                    # Safe Ruby-based copy"
    echo "  $0 stats                   # Show statistics"
    echo "  $0 verify                  # Verify data integrity"
    echo ""
    echo "Note: This assumes that all records already have their region_id and"
    echo "      global_context set correctly (via region_taggings:update_all_region_id)"
}

# Function to run the cleanup
run_cleanup() {
    local method=$1
    
    echo "Starting version cleanup..."
    echo "Method: $method"
    echo ""
    
    case $method in
        "fast")
            echo "Running SQL-based copy (FASTEST)..."
            bundle exec rails version_cleanup:copy_region_data_sql
            ;;
        "safe")
            echo "Running Ruby-based copy (SAFER)..."
            bundle exec rails version_cleanup:copy_region_data
            ;;
        "stats")
            echo "Showing version statistics..."
            bundle exec rails version_cleanup:stats
            ;;
        "verify")
            echo "Verifying version data..."
            bundle exec rails version_cleanup:verify
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