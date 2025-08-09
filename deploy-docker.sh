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
    SSH_CMD="ssh -p $SERVER_PORT -A $SERVER_USER@$SERVER_HOST"
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
        SSH_CMD="ssh -A $SERVER_USER@$SERVER_HOST"
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
        DATABASE_PASSWORD="carambus_production_password"
        WEB_PORT="3000"
        POSTGRES_PORT="5432"
        REDIS_PORT="6379"
        DOMAIN=""
        USE_HTTPS="false"
        ;;
    carambus_newapi|newapi)
        DB_DUMP_FILE="carambus_api_development_20250804_0218_fixed.sql.gz"
        DATABASE_NAME="carambus_api_production"
        DATABASE_USER="www_data"
        DATABASE_PASSWORD="carambus_newapi_production_password"
        WEB_PORT="3001"
        POSTGRES_PORT="5433"
        REDIS_PORT="6380"
        DOMAIN="newapi.carambus.de"
        USE_HTTPS="true"
        ;;
    carambus_local|local)
        DB_DUMP_FILE="carambus_production_20250805_224054_fixed.sql.gz"
        DATABASE_NAME="carambus_development"
        DATABASE_USER="www_data"
        DATABASE_PASSWORD="carambus_development_password"
        WEB_PORT="3000"
        POSTGRES_PORT="5432"
        REDIS_PORT="6379"
        DOMAIN=""
        USE_HTTPS="false"
        ;;
    *)
        print_error "Unknown deployment name: $DEPLOYMENT_NAME"
        print_status "Available deployments: carambus_raspberry, carambus_newapi, carambus_local"
        exit 1
        ;;
esac

print_header "Deploying $DEPLOYMENT_NAME to $TARGET_SERVER:$TARGET_PATH"

# Show all configuration parameters
print_status "Configuration parameters:"
echo "  Deployment Name: $DEPLOYMENT_NAME"
echo "  Target Server: $TARGET_SERVER"
echo "  Target Path: $TARGET_PATH"
echo "  Database Name: $DATABASE_NAME"
echo "  Database User: $DATABASE_USER"
echo "  Database Password: $DATABASE_PASSWORD"
echo "  Database Dump: $DB_DUMP_FILE"
echo "  Web Port: $WEB_PORT"
echo "  PostgreSQL Port: $POSTGRES_PORT"
echo "  Redis Port: $REDIS_PORT"
echo "  Domain: $DOMAIN"
echo "  Use HTTPS: $USE_HTTPS"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with this configuration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled by user"
    exit 0
fi

# Check if SSH agent is running and has keys
if [ "$SERVER_HOST" != "localhost" ]; then
    print_status "Checking SSH agent..."
    if ! ssh-add -l >/dev/null 2>&1; then
        print_warning "SSH agent not running or no keys loaded"
        print_status "Please run: ssh-add ~/.ssh/id_rsa (or your key)"
        print_status "Then run this script again"
        exit 1
    fi
    print_status "SSH agent is ready"
fi

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
DATABASE_PASSWORD=$DATABASE_PASSWORD
REDIS_DB=0
WEB_PORT=$WEB_PORT
POSTGRES_PORT=$POSTGRES_PORT
REDIS_PORT=$REDIS_PORT
DB_DUMP_FILE=$DB_DUMP_FILE
DOMAIN=$DOMAIN
USE_HTTPS=$USE_HTTPS
EOF

# Step 1: Prepare server
print_status "Step 1: Preparing server..."

if [ "$SERVER_HOST" != "localhost" ]; then
    $SSH_CMD << EOF
        # Create deployment directory (handle www-data user's home directory)
        if [ "\$USER" = "www-data" ]; then
            # www-data user's home is /var/www
            DEPLOY_PATH="/var/www/carambus_newapi"
        else
            DEPLOY_PATH="$TARGET_PATH"
        fi
        
        mkdir -p \$DEPLOY_PATH
        cd \$DEPLOY_PATH
        
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
        
        # Set correct permissions for www-data user
        if [ "\$USER" = "www-data" ]; then
            sudo chown -R www-data:www-data \$DEPLOY_PATH
        fi
EOF
else
    mkdir -p $TARGET_PATH
    mkdir -p $TARGET_PATH/doc/doc-local/docker
    mkdir -p $TARGET_PATH/config/credentials
    mkdir -p $TARGET_PATH/storage $TARGET_PATH/log $TARGET_PATH/tmp
fi

# Determine the correct deployment path
if [ "$SERVER_HOST" != "localhost" ] && [ "$SERVER_USER" = "www-data" ]; then
    DEPLOY_PATH="/var/www/carambus_newapi"
else
    DEPLOY_PATH="$TARGET_PATH"
fi

# Step 2: Clone or update repository
print_status "Step 2: Setting up repository..."

if [ "$SERVER_HOST" != "localhost" ]; then
    $SSH_CMD << EOF
        # Use the correct deployment path for www-data user
        if [ "\$USER" = "www-data" ]; then
            DEPLOY_PATH="/var/www/carambus_newapi"
        else
            DEPLOY_PATH="$TARGET_PATH"
        fi
        
        mkdir -p \$DEPLOY_PATH
        cd \$DEPLOY_PATH
        
        # Clone repository if it doesn't exist, otherwise pull latest
        if [ ! -d ".git" ]; then
            echo "Cloning repository..."
            if [ -d "." ] && [ "\$(ls -A)" ]; then
                echo "Directory not empty, removing contents..."
                rm -rf ./*
                rm -rf ./.* 2>/dev/null || true
            fi
            # Use SSH for GitHub access
            git clone git@github.com:GernotUllrich/carambus.git .
        else
            echo "Pulling latest changes..."
            git pull origin master
        fi
        
        # Create necessary directories
        mkdir -p doc/doc-local/docker
        mkdir -p config/credentials
        mkdir -p storage log tmp
        
        # Set correct permissions for www-data user
        if [ "\$USER" = "www-data" ]; then
            sudo chown -R www-data:www-data \$DEPLOY_PATH
        fi
EOF
else
    mkdir -p $DEPLOY_PATH
    if [ ! -d "$DEPLOY_PATH/.git" ]; then
        git clone https://github.com/GernotUllrich/carambus.git $DEPLOY_PATH
    else
        cd $DEPLOY_PATH
        git pull origin master
    fi
fi

# Step 3: Copy database dump
print_status "Step 3: Copying database dump..."
if [ "$SERVER_HOST" != "localhost" ]; then
    $SCP_CMD "$DB_DUMP_PATH" $SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/doc/doc-local/docker/ 2>/dev/null
else
    cp "$DB_DUMP_PATH" $DEPLOY_PATH/doc/doc-local/docker/ 2>/dev/null
fi

# Step 4: Copy credentials (if they exist)
if [ -d "config/credentials" ]; then
    print_status "Step 4: Copying credentials..."
    if [ "$SERVER_HOST" != "localhost" ]; then
        $SCP_CMD -r config/credentials/* $SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/config/credentials/ 2>/dev/null
    else
        cp -r config/credentials/* $DEPLOY_PATH/config/credentials/ 2>/dev/null
    fi
else
    print_warning "No credentials found in config/credentials/"
fi

# Step 4b: Copy SSL certificates if HTTPS is enabled
if [ "$USE_HTTPS" = "true" ] && [ -n "$DOMAIN" ]; then
    print_status "Step 4b: Copying SSL certificates for $DOMAIN..."
    
    # Check if certificates exist locally
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        if [ "$SERVER_HOST" != "localhost" ]; then
            # Create certificates directory on remote server
            $SSH_CMD "mkdir -p $DEPLOY_PATH/ssl-certs"
            
            # Copy certificates
            $SCP_CMD -r "/etc/letsencrypt/live/$DOMAIN" $SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/ssl-certs/ 2>/dev/null
            $SCP_CMD -r "/etc/letsencrypt/archive/$DOMAIN" $SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/ssl-certs/ 2>/dev/null
            
            # Set up symlinks on remote server
            $SSH_CMD << EOF
                cd $DEPLOY_PATH/ssl-certs
                if [ -d "$DOMAIN" ]; then
                    # Create symlinks for nginx
                    sudo mkdir -p /etc/letsencrypt/live/$DOMAIN
                    sudo mkdir -p /etc/letsencrypt/archive/$DOMAIN
                    sudo cp -r $DOMAIN/* /etc/letsencrypt/live/$DOMAIN/
                    sudo cp -r archive_$DOMAIN/* /etc/letsencrypt/archive/$DOMAIN/ 2>/dev/null || true
                    echo "SSL certificates copied and symlinked for $DOMAIN"
                else
                    echo "Warning: SSL certificates not found locally"
                fi
EOF
        else
            # Local copy
            mkdir -p $DEPLOY_PATH/ssl-certs
            cp -r "/etc/letsencrypt/live/$DOMAIN" $DEPLOY_PATH/ssl-certs/
            cp -r "/etc/letsencrypt/archive/$DOMAIN" $DEPLOY_PATH/ssl-certs/ 2>/dev/null || true
        fi
    else
        print_warning "SSL certificates not found locally at /etc/letsencrypt/live/$DOMAIN"
        print_warning "HTTPS will not work until certificates are manually installed"
    fi
fi

# Step 5: Copy .env file
print_status "Step 5: Copying environment configuration..."
if [ "$SERVER_HOST" != "localhost" ]; then
    $SCP_CMD .env.$DEPLOYMENT_NAME $SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/.env 2>/dev/null
else
    cp .env.$DEPLOYMENT_NAME $DEPLOY_PATH/.env 2>/dev/null
fi

# Step 5b: Install host nginx configuration for newapi
if [ "$DEPLOYMENT_NAME" = "carambus_newapi" ] || [ "$DEPLOYMENT_NAME" = "newapi" ]; then
    print_status "Step 5b: Installing host nginx configuration for newapi..."
    if [ "$SERVER_HOST" != "localhost" ]; then
        # Copy nginx configurations
        $SCP_CMD nginx-host-config/newapi.carambus.de $SERVER_USER@$SERVER_HOST:/tmp/newapi.carambus.de 2>/dev/null
        $SCP_CMD nginx-host-config/docker_carambus_newapi_upstream $SERVER_USER@$SERVER_HOST:/tmp/docker_carambus_newapi_upstream 2>/dev/null
        
        # Install nginx configurations
        $SSH_CMD << EOF
            # Install site configuration
            sudo cp /tmp/newapi.carambus.de /etc/nginx/sites-available/newapi.carambus.de
            sudo ln -sf /etc/nginx/sites-available/newapi.carambus.de /etc/nginx/sites-enabled/newapi.carambus.de
            
            # Install upstream configuration
            sudo cp /tmp/docker_carambus_newapi_upstream /etc/nginx/sites-available/docker_carambus_newapi_upstream
            sudo ln -sf /etc/nginx/sites-available/docker_carambus_newapi_upstream /etc/nginx/sites-enabled/docker_carambus_newapi_upstream
            
            # Test nginx configuration
            sudo nginx -t
            
            # Reload nginx if configuration is valid
            if sudo nginx -t; then
                sudo systemctl reload nginx
                echo "Nginx configuration installed and reloaded successfully"
            else
                echo "Nginx configuration test failed"
                exit 1
            fi
            
            # Clean up temporary files
            rm -f /tmp/newapi.carambus.de /tmp/docker_carambus_newapi_upstream
EOF
    else
        echo "Local deployment: nginx configuration needs manual installation"
    fi
fi

# Step 6: Deploy on server
print_status "Step 6: Deploying on server..."

if [ "$SERVER_HOST" != "localhost" ]; then
    $SSH_CMD << EOF
        # Use the correct deployment path for www-data user
        if [ "\$USER" = "www-data" ]; then
            DEPLOY_PATH="/var/www/carambus_newapi"
        else
            DEPLOY_PATH="$TARGET_PATH"
        fi
        
        cd \$DEPLOY_PATH
        
        # Stop any existing containers
        docker compose down 2>/dev/null || true
        
        # Remove old volumes if they exist
        docker volume rm ${DEPLOYMENT_NAME}_postgres_data ${DEPLOYMENT_NAME}_redis_data 2>/dev/null || true
        
        # Build and start services
        echo "Building Docker images..."
        docker compose build --quiet
        
        echo "Starting services..."
        docker compose up -d
        
        # Wait for services to be ready
        echo "Waiting for services to be ready..."
        sleep 30
        
        # Check if services are running
        echo "Checking service status..."
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        
        # Test the application
        echo "Testing application endpoint..."
        if curl -f -s http://localhost:$WEB_PORT > /dev/null; then
            echo "✅ Application is responding on port $WEB_PORT"
        else
            echo "❌ Application is not responding on port $WEB_PORT"
            echo "Recent logs:"
            docker compose logs --tail=20 web
        fi
        
        # Test HTTPS endpoint if domain is configured
        if [ -n "$DOMAIN" ]; then
            echo "Testing HTTPS endpoint..."
            if curl -f -s -k https://$DOMAIN > /dev/null; then
                echo "✅ HTTPS endpoint is responding"
            else
                echo "⚠️ HTTPS endpoint not responding (certificates may need to be set up)"
            fi
        fi
EOF
else
    cd $DEPLOY_PATH
    
    # Stop any existing containers
    docker compose down 2>/dev/null || true
    
    # Remove old volumes if they exist
    docker volume rm ${DEPLOYMENT_NAME}_postgres_data ${DEPLOYMENT_NAME}_redis_data 2>/dev/null || true
    
    # Build and start services
    print_status "Building Docker images..."
    docker compose build --quiet
    
    print_status "Starting services..."
    docker compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 30
    
    # Check if services are running
    print_status "Checking service status..."
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    
    # Test the application
    print_status "Testing application endpoint..."
    if curl -f -s http://localhost:$WEB_PORT > /dev/null; then
        print_status "✅ Application is responding on port $WEB_PORT"
    else
        print_error "❌ Application is not responding on port $WEB_PORT"
        docker compose logs --tail=20 web
    fi
fi

print_header "Deployment completed!"
print_status "Deployment: $DEPLOYMENT_NAME"
if [ "$SERVER_HOST" != "localhost" ] && [ "$SERVER_USER" = "www-data" ]; then
    print_status "Target: $TARGET_SERVER:/var/www/carambus_newapi"
    print_status "Docker logs: $SSH_CMD 'cd /var/www/carambus_newapi && docker compose logs -f'"
else
    print_status "Target: $TARGET_SERVER:$TARGET_PATH"
    print_status "Docker logs: $SSH_CMD 'cd $TARGET_PATH && docker compose logs -f'"
fi
print_status "Database: $DATABASE_NAME"
print_status "Web Port: $WEB_PORT"

# Clean up .env file
rm -f .env.$DEPLOYMENT_NAME 