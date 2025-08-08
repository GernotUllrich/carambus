#!/bin/bash

# Carambus Docker Deployment Script
# Usage: ./deploy-docker.sh [deployment_name] [target_server] [target_path]
#
# Examples:
#   ./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus
#   ./deploy-docker.sh carambus_newapi www-data@carambus-de:8910 /home/www-data/carambus_newapi
#   ./deploy-docker.sh carambus_local localhost /tmp/carambus_test

set -e

# Default values
DEPLOYMENT_NAME=${1:-carambus}
TARGET_SERVER=${2:-localhost}
TARGET_PATH=${3:-./carambus}

# Parse server connection details
if [[ $TARGET_SERVER == *":"* ]]; then
    # Format: user@host:port
    SERVER_USER=$(echo $TARGET_SERVER | cut -d@ -f1)
    SERVER_HOST=$(echo $TARGET_SERVER | cut -d@ -f2 | cut -d: -f1)
    SERVER_PORT=$(echo $TARGET_SERVER | cut -d: -f2)
    SSH_CMD="ssh -p $SERVER_PORT $SERVER_USER@$SERVER_HOST"
    SCP_CMD="scp -P $SERVER_PORT"
else
    # Format: user@host or localhost
    if [[ $TARGET_SERVER == "localhost" ]]; then
        SERVER_USER=""
        SERVER_HOST="localhost"
        SERVER_PORT=""
        SSH_CMD=""
        SCP_CMD="cp"
    else
        SERVER_USER=$(echo $TARGET_SERVER | cut -d@ -f1)
        SERVER_HOST=$(echo $TARGET_SERVER | cut -d@ -f2)
        SERVER_PORT=""
        SSH_CMD="ssh $SERVER_USER@$SERVER_HOST"
        SCP_CMD="scp"
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Configuration based on deployment name
case $DEPLOYMENT_NAME in
    carambus_raspberry|carambus_pi)
        DB_DUMP_FILE="carambus_production_fixed.sql.gz"
        DATABASE_NAME="carambus_production"
        DATABASE_USER="www_data"
        WEB_PORT="3000"
        POSTGRES_PORT="5432"
        REDIS_PORT="6379"
        DOMAIN=""
        ;;
    carambus_newapi|newapi)
        DB_DUMP_FILE="carambus_api_development_20250804_0218.sql.gz"
        DATABASE_NAME="carambus_api_production"
        DATABASE_USER="www_data"
        WEB_PORT="3000"
        POSTGRES_PORT="5432"
        REDIS_PORT="6379"
        DOMAIN="newapi.carambus.de"
        ;;
    carambus_local|local)
        DB_DUMP_FILE="carambus_production_fixed.sql.gz"
        DATABASE_NAME="carambus_development"
        DATABASE_USER="www_data"
        WEB_PORT="3000"
        POSTGRES_PORT="5432"
        REDIS_PORT="6379"
        DOMAIN=""
        ;;
    *)
        print_error "Unknown deployment name: $DEPLOYMENT_NAME"
        print_status "Available deployments: carambus_raspberry, carambus_newapi, carambus_local"
        exit 1
        ;;
esac

print_header "Deploying $DEPLOYMENT_NAME to $TARGET_SERVER:$TARGET_PATH"

# Check if database dump exists
DB_DUMP_PATH="doc/doc-local/docker/$DB_DUMP_FILE"
if [ ! -f "$DB_DUMP_PATH" ]; then
    print_error "Database dump not found: $DB_DUMP_PATH"
    exit 1
fi

print_status "Database dump found: $DB_DUMP_PATH"

# Create .env file for this deployment
print_status "Creating .env file for $DEPLOYMENT_NAME..."
cat > .env.$DEPLOYMENT_NAME << EOF
# Carambus Docker Environment Configuration
# Deployment: $DEPLOYMENT_NAME
# Target: $TARGET_SERVER:$TARGET_PATH

DEPLOYMENT_NAME=$DEPLOYMENT_NAME
DATABASE_NAME=$DATABASE_NAME
DATABASE_USER=$DATABASE_USER
DATABASE_PASSWORD=${DEPLOYMENT_NAME}_production_password
REDIS_DB=0
WEB_PORT=$WEB_PORT
POSTGRES_PORT=$POSTGRES_PORT
REDIS_PORT=$REDIS_PORT
DB_DUMP_FILE=$DB_DUMP_FILE
DOMAIN=$DOMAIN
EOF

# Step 1: Prepare server
print_status "Step 1: Preparing server..."

if [ "$SERVER_HOST" != "localhost" ]; then
    $SSH_CMD << EOF
        # Create deployment directory
        mkdir -p $TARGET_PATH
        cd $TARGET_PATH
        
        # Install Docker if not present
        if ! command -v docker &> /dev/null; then
            print_status "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            sudo usermod -aG docker \$USER
            rm get-docker.sh
        fi
        
        # Install Docker Compose if not present
        if ! command -v docker compose &> /dev/null; then
            print_status "Installing Docker Compose..."
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        # Create necessary directories
        mkdir -p doc/doc-local/docker
        mkdir -p config/credentials
        mkdir -p storage log tmp
EOF
else
    mkdir -p $TARGET_PATH
    mkdir -p $TARGET_PATH/doc/doc-local/docker
    mkdir -p $TARGET_PATH/config/credentials
    mkdir -p $TARGET_PATH/storage $TARGET_PATH/log $TARGET_PATH/tmp
fi

# Step 2: Copy application files
print_status "Step 2: Copying application files..."

# Create a temporary directory for files to copy
TEMP_DIR=$(mktemp -d)
cp -r . $TEMP_DIR/
rm -rf $TEMP_DIR/.git $TEMP_DIR/node_modules $TEMP_DIR/tmp $TEMP_DIR/log

# Copy files to target
if [ "$SERVER_HOST" != "localhost" ]; then
    $SCP_CMD -r $TEMP_DIR/* $SERVER_USER@$SERVER_HOST:$TARGET_PATH/
else
    cp -r $TEMP_DIR/* $TARGET_PATH/
fi

# Clean up temp directory
rm -rf $TEMP_DIR

# Step 3: Copy database dump
print_status "Step 3: Copying database dump..."
if [ "$SERVER_HOST" != "localhost" ]; then
    $SCP_CMD "$DB_DUMP_PATH" $SERVER_USER@$SERVER_HOST:$TARGET_PATH/doc/doc-local/docker/
else
    cp "$DB_DUMP_PATH" $TARGET_PATH/doc/doc-local/docker/
fi

# Step 4: Copy credentials (if they exist)
if [ -d "config/credentials" ]; then
    print_status "Step 4: Copying credentials..."
    if [ "$SERVER_HOST" != "localhost" ]; then
        $SCP_CMD -r config/credentials/* $SERVER_USER@$SERVER_HOST:$TARGET_PATH/config/credentials/
    else
        cp -r config/credentials/* $TARGET_PATH/config/credentials/
    fi
else
    print_warning "No credentials found in config/credentials/"
fi

# Step 5: Copy .env file
print_status "Step 5: Copying environment configuration..."
if [ "$SERVER_HOST" != "localhost" ]; then
    $SCP_CMD .env.$DEPLOYMENT_NAME $SERVER_USER@$SERVER_HOST:$TARGET_PATH/.env
else
    cp .env.$DEPLOYMENT_NAME $TARGET_PATH/.env
fi

# Step 6: Deploy on server
print_status "Step 6: Deploying on server..."

if [ "$SERVER_HOST" != "localhost" ]; then
    $SSH_CMD << EOF
        cd $TARGET_PATH
        
        # Stop any existing containers
        docker compose down 2>/dev/null || true
        
        # Remove old volumes if they exist
        docker volume rm ${DEPLOYMENT_NAME}_postgres_data ${DEPLOYMENT_NAME}_redis_data 2>/dev/null || true
        
        # Build and start services
        print_status "Building Docker images..."
        docker compose build
        
        print_status "Starting services..."
        docker compose up -d
        
        # Wait for services to be ready
        print_status "Waiting for services to be ready..."
        sleep 30
        
        # Check if services are running
        print_status "Checking service status..."
        docker compose ps
        
        # Test the application
        print_status "Testing application endpoint..."
        if curl -f -s http://localhost:$WEB_PORT > /dev/null; then
            print_status "✅ Application is responding on port $WEB_PORT"
        else
            print_error "❌ Application is not responding on port $WEB_PORT"
            docker compose logs web
        fi
        
        # Test HTTPS endpoint if domain is configured
        if [ -n "$DOMAIN" ]; then
            print_status "Testing HTTPS endpoint..."
            if curl -f -s -k https://$DOMAIN > /dev/null; then
                print_status "✅ HTTPS endpoint is responding"
            else
                print_warning "⚠️ HTTPS endpoint not responding (certificates may need to be set up)"
            fi
        fi
EOF
else
    cd $TARGET_PATH
    
    # Stop any existing containers
    docker compose down 2>/dev/null || true
    
    # Remove old volumes if they exist
    docker volume rm ${DEPLOYMENT_NAME}_postgres_data ${DEPLOYMENT_NAME}_redis_data 2>/dev/null || true
    
    # Build and start services
    print_status "Building Docker images..."
    docker compose build
    
    print_status "Starting services..."
    docker compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 30
    
    # Check if services are running
    print_status "Checking service status..."
    docker compose ps
    
    # Test the application
    print_status "Testing application endpoint..."
    if curl -f -s http://localhost:$WEB_PORT > /dev/null; then
        print_status "✅ Application is responding on port $WEB_PORT"
    else
        print_error "❌ Application is not responding on port $WEB_PORT"
        docker compose logs web
    fi
fi

print_header "Deployment completed!"
print_status "Deployment: $DEPLOYMENT_NAME"
print_status "Target: $TARGET_SERVER:$TARGET_PATH"
print_status "Database: $DATABASE_NAME"
print_status "Web Port: $WEB_PORT"

if [ "$SERVER_HOST" != "localhost" ]; then
    print_status "Docker logs: $SSH_CMD 'cd $TARGET_PATH && docker compose logs -f'"
else
    print_status "Docker logs: cd $TARGET_PATH && docker compose logs -f"
fi

# Clean up .env file
rm -f .env.$DEPLOYMENT_NAME 