#!/bin/bash

# Carambus Docker Setup Test Script
# Tests all components of the Docker setup

echo "🔍 Testing Carambus Docker Setup..."
echo "=================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

success_count=0
total_tests=0

# 1. Test Docker
echo "1. Testing Docker..."
total_tests=$((total_tests + 1))
if command -v docker &> /dev/null; then
    print_status 0 "Docker is installed and running"
    success_count=$((success_count + 1))
else
    print_status 1 "Docker is not installed"
fi

total_tests=$((total_tests + 1))
if docker compose version &> /dev/null; then
    print_status 0 "Docker Compose is available"
    success_count=$((success_count + 1))
else
    print_status 1 "Docker Compose is not available"
fi

# 2. Test project setup
echo
echo "2. Testing project setup..."
total_tests=$((total_tests + 1))
if [ -f "docker-compose.yml" ]; then
    print_status 0 "docker-compose.yml found"
    success_count=$((success_count + 1))
else
    print_status 1 "docker-compose.yml not found"
fi

# 3. Test production data
echo
echo "3. Testing production data..."
total_tests=$((total_tests + 1))
if [ -f "doc/doc-local/docker/carambus_production_fixed.sql.gz" ] || [ -f "doc/doc-local/docker/carambus_production_20250805_224054.sql.gz" ]; then
    print_status 0 "Database dump found"
    success_count=$((success_count + 1))
else
    print_status 1 "Database dump missing"
fi

total_tests=$((total_tests + 1))
if [ -f "doc/doc-local/docker/shared/config/credentials/production.key" ] && [ -f "doc/doc-local/docker/shared/config/credentials/production.yml.enc" ]; then
    print_status 0 "Rails credentials found"
    success_count=$((success_count + 1))
else
    print_status 1 "Rails credentials missing"
fi

total_tests=$((total_tests + 1))
if [ -f "REVISION" ]; then
    print_status 0 "REVISION file found"
    success_count=$((success_count + 1))
else
    print_status 1 "REVISION file missing"
fi

# 4. Test Docker services
echo
echo "4. Testing Docker services..."
if ! docker compose ps &> /dev/null; then
    print_status 1 "Docker services are not running"
    echo "Starting services..."
    docker compose up -d
    sleep 30
fi

total_tests=$((total_tests + 1))
if docker compose ps | grep -q "postgres.*Up"; then
    print_status 0 "postgres service is running"
    success_count=$((success_count + 1))
else
    print_status 1 "postgres service is not running"
fi

total_tests=$((total_tests + 1))
if docker compose ps | grep -q "redis.*Up"; then
    print_status 0 "redis service is running"
    success_count=$((success_count + 1))
else
    print_status 1 "redis service is not running"
fi

total_tests=$((total_tests + 1))
if docker compose ps | grep -q "web.*Up"; then
    print_status 0 "web service is running"
    success_count=$((success_count + 1))
else
    print_status 1 "web service is not running"
fi

# 5. Test database
echo
echo "5. Testing database..."
total_tests=$((total_tests + 1))
if docker compose exec postgres pg_isready -U www_data -d carambus_production &> /dev/null; then
    print_status 0 "PostgreSQL is ready"
    success_count=$((success_count + 1))
else
    print_status 1 "PostgreSQL is not ready"
fi

# 6. Test web application
echo
echo "6. Testing web application..."
total_tests=$((total_tests + 1))
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login | grep -q "200\|301\|302"; then
    print_status 0 "Web application is responding"
    success_count=$((success_count + 1))
else
    print_status 1 "Web application is not responding"
fi

# 7. Test asset pipeline
echo
echo "7. Testing asset pipeline..."
total_tests=$((total_tests + 1))
if curl -s http://localhost:3000/login | grep -q "stylesheet"; then
    print_status 0 "CSS is loading"
    success_count=$((success_count + 1))
else
    print_status 1 "CSS is not loading"
fi

total_tests=$((total_tests + 1))
if curl -s http://localhost:3000/login | grep -q "script"; then
    print_status 0 "JavaScript is loading"
    success_count=$((success_count + 1))
else
    print_status 1 "JavaScript is not loading"
fi

# 8. Check for errors
echo
echo "8. Checking for errors..."
total_tests=$((total_tests + 1))
recent_errors=$(docker compose logs --tail=50 2>&1 | grep -E "(ERROR|FATAL|Exception)" | grep -v "version obsolete" | grep -v "No route matches.*health" | tail -5)

if [ -z "$recent_errors" ]; then
    print_status 0 "No critical errors found in logs"
    success_count=$((success_count + 1))
else
    print_status 1 "Found errors in logs"
    echo "Recent errors:"
    echo "$recent_errors"
fi

# Summary
echo
echo "📊 Summary"
echo "=========="
echo "Tests passed: $success_count/$total_tests"

if [ $success_count -eq $total_tests ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed. Please check the issues above.${NC}"
fi

echo
echo "📝 Next steps:"
echo "1. Test the application from a web browser"
echo "2. Verify scoreboard functionality"
echo "3. Check resource usage: docker stats"
echo "4. Monitor logs: docker compose logs -f" 