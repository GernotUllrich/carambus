#!/bin/bash

# Carambus Multi-Environment Deployment Script
# Automatisiertes Deployment für verschiedene Umgebungen

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECTS_DIR="/Volumes/EXT2TB/gullrich/DEV/projects"
DATA_DIR="/Volumes/EXT2TB/gullrich/DEV/carambus_data"
SERVER_HOST="carambus.de"
SERVER_PORT="8910"
SERVER_USER="www-data"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists bundle; then
        print_error "Bundler not found. Please install Bundler first."
        exit 1
    fi
    
    if ! command_exists git; then
        print_error "Git not found. Please install Git first."
        exit 1
    fi
    
    if ! command_exists ssh; then
        print_error "SSH not found. Please install SSH first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to pull repo changes
pull_repo_changes() {
    local repo_path=$1
    local repo_name=$2
    
    print_status "Pulling latest changes for $repo_name..."
    
    if [ ! -d "$repo_path" ]; then
        print_error "Repository directory not found: $repo_path"
        exit 1
    fi
    
    cd "$repo_path"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        print_error "Not a git repository: $repo_path"
        exit 1
    fi
    
    # Fetch latest changes
    print_status "Fetching latest changes..."
    git fetch carambus
    
    # Check if there are any changes to pull
    if [ "$(git rev-list HEAD..carambus/master --count)" -eq 0 ]; then
        print_warning "No new changes to pull for $repo_name"
    else
        print_status "Pulling changes from carambus/master..."
        git pull carambus master
        print_success "Successfully pulled changes for $repo_name"
    fi
}

# Function to create environment
create_environment() {
    local env_name=$1
    local repo_name=$2
    
    print_status "Creating environment: $env_name"
    
    # Create project directory
    if [ ! -d "$PROJECTS_DIR/$repo_name" ]; then
        print_status "Creating repository: $repo_name"
        cd "$PROJECTS_DIR"
        cp -r carambus_api "$repo_name"
        cd "$repo_name"
        rm -rf .git
        git init
        git remote add origin git@github.com:Geullrich/carambus_api.git
        print_success "Repository created: $repo_name"
    else
        print_warning "Repository already exists: $repo_name"
    fi
    
    # Create data directory
    if [ ! -d "$DATA_DIR/$env_name" ]; then
        print_status "Creating data directory: $env_name"
        mkdir -p "$DATA_DIR/$env_name"/{config,credentials,environments,database_dumps,deploy}
        print_success "Data directory created: $env_name"
    else
        print_warning "Data directory already exists: $env_name"
    fi
}

# Function to deploy API server
deploy_api_server() {
    print_status "Deploying API server..."
    
    # Pull latest changes first
    pull_repo_changes "$PROJECTS_DIR/carambus_api" "carambus_api"
    
    cd "$PROJECTS_DIR/carambus_api"
    
    # Check if we're in the right directory
    if [ ! -f "Gemfile" ]; then
        print_error "Not in a Rails project directory"
        exit 1
    fi
    
    # Set data directory
    print_status "Setting data directory..."
    bundle exec rails 'data:set_directory[api_server]'
    
    # Configure mode
    print_status "Configuring API mode..."
    MODE_BASENAME=carambus_api \
    MODE_DOMAIN=newapi.carambus.de \
    MODE_SSL_ENABLED=true \
    MODE_HOST=$SERVER_HOST \
    MODE_PORT=$SERVER_PORT \
    MODE_NGINX_PORT=80 \
    MODE_PUMA_SOCKET=/var/www/carambus_api/shared/sockets/puma-production.sock \
    bundle exec rails mode:api
    
    # Generate templates
    print_status "Generating templates..."
    bundle exec rails data:generate_templates
    
    # Deploy to repository
    print_status "Deploying to repository..."
    bundle exec rails data:deploy
    
    # Capistrano deployment
    print_status "Starting Capistrano deployment..."
    bundle exec cap production deploy
    
    print_success "API server deployment completed"
}

# Function to deploy local server
deploy_local_server() {
    print_status "Deploying local server..."
    
    # Pull latest changes first
    pull_repo_changes "$PROJECTS_DIR/carambus_local_hetzner" "carambus_local_hetzner"
    
    cd "$PROJECTS_DIR/carambus_local_hetzner"
    
    # Check if we're in the right directory
    if [ ! -f "Gemfile" ]; then
        print_error "Not in a Rails project directory"
        exit 1
    fi
    
    # Set data directory
    print_status "Setting data directory..."
    bundle exec rails 'data:set_directory[local_hetzner]'
    
    # Configure mode
    print_status "Configuring local mode..."
    MODE_BASENAME=carambus \
    MODE_DOMAIN=new.carambus.de \
    MODE_SSL_ENABLED=true \
    MODE_HOST=$SERVER_HOST \
    MODE_PORT=$SERVER_PORT \
    MODE_NGINX_PORT=80 \
    MODE_PUMA_SOCKET=/var/www/carambus/shared/sockets/puma-production.sock \
    bundle exec rails mode:local
    
    # Generate templates
    print_status "Generating templates..."
    bundle exec rails data:generate_templates
    
    # Deploy to repository
    print_status "Deploying to repository..."
    bundle exec rails data:deploy
    
    # Capistrano deployment
    print_status "Starting Capistrano deployment..."
    bundle exec cap production deploy
    
    print_success "Local server deployment completed"
}

# Function to create database from API database
create_database_from_api() {
    print_status "Creating database from API database..."
    
    # Step 1: Dump API database on server
    print_status "Step 1: Dumping API database on server..."
    ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << 'EOF'
        cd /var/www/carambus_api/current
        pg_dump -Uwww_data carambus_api_production | gzip > carambus_api_production.sql.gz
        echo "Database dump created: carambus_api_production.sql.gz"
EOF
    
    # Step 2: Download dump to local machine
    print_status "Step 2: Downloading database dump..."
    scp -P $SERVER_PORT $SERVER_USER@$SERVER_HOST:/var/www/carambus_api/current/carambus_api_production.sql.gz /tmp/
    
    # Step 3: Restore to local server database
    print_status "Step 3: Restoring to local server database..."
    ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << 'EOF'
        # Stop Puma service
        sudo systemctl stop puma-carambus.service
        
        # Drop and recreate database
        DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production bundle exec rake db:drop
        sudo -u postgres psql postgres -c "CREATE DATABASE carambus_production;"
        sudo -u postgres psql postgres -c "ALTER DATABASE carambus_production OWNER TO www_data;"
        
        # Restore database
        gunzip -c /var/www/carambus_api/current/carambus_api_production.sql.gz | sudo -u postgres psql carambus_production
        
        # Start Puma service
        sudo systemctl start puma-carambus.service
        
        echo "Database restored successfully"
EOF
    
    print_success "Database creation from API completed"
}

# Function to post-deploy setup
post_deploy_setup() {
    print_status "Running post-deploy setup..."
    
    ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << 'EOF'
        cd /var/www/carambus/current
        
        # Sequence Reset
        echo "Running sequence reset..."
        RAILS_ENV=production bundle exec rails runner "Version.sequence_reset"
        
        # Create Scoreboard User
        echo "Creating scoreboard user..."
        RAILS_ENV=production bundle exec rails runner "
          User.create!(
            name: 'Scoreboard',
            email: 'scoreboard@carambus.de',
            password: 'scoreboard',
            password_confirmation: 'scoreboard',
            admin: false,
            terms_of_service: true,
            confirmed_at: Time.now
          ) unless User.find_by(email: 'scoreboard@carambus.de')
        "
        
        # Get last version ID from API server
        echo "Getting last version ID from API server..."
        LAST_VERSION_ID=$(ssh -p 8910 www-data@carambus.de "cd /var/www/carambus_api/current && RAILS_ENV=production bundle exec rails runner 'puts PaperTrail::Version.last.id'")
        
        # Set last version ID on local server
        echo "Setting last version ID: $LAST_VERSION_ID"
        RAILS_ENV=production bundle exec rails runner "Setting.key_set_value('last_version_id', $LAST_VERSION_ID)"
        
        echo "Post-deploy setup completed"
EOF
    
    print_success "Post-deploy setup completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  create-env <env_name> <repo_name>  Create new environment"
    echo "  deploy-api                          Deploy API server"
    echo "  deploy-local                        Deploy local server"
    echo "  create-db                           Create database from API"
    echo "  post-setup                          Run post-deploy setup"
    echo "  full-local                          Full local server deployment"
    echo "  check                               Check prerequisites"
    echo "  help                                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 create-env local_hetzner carambus_local_hetzner"
    echo "  $0 deploy-api"
    echo "  $0 full-local"
}

# Main script logic
main() {
    case "${1:-help}" in
        "create-env")
            if [ -z "$2" ] || [ -z "$3" ]; then
                print_error "Environment name and repository name required"
                show_usage
                exit 1
            fi
            create_environment "$2" "$3"
            ;;
        "deploy-api")
            check_prerequisites
            deploy_api_server
            ;;
        "deploy-local")
            check_prerequisites
            deploy_local_server
            ;;
        "create-db")
            create_database_from_api
            ;;
        "post-setup")
            post_deploy_setup
            ;;
        "full-local")
            check_prerequisites
            deploy_local_server
            create_database_from_api
            post_deploy_setup
            ;;
        "check")
            check_prerequisites
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function
main "$@"
