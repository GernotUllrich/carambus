#!/bin/bash

# Test Documentation Structure Script
# This script verifies that the documentation is correctly built and accessible

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DOCS_DIR="public/docs"
PASSED=0
FAILED=0

echo "========================================="
echo "Testing Documentation Structure"
echo "========================================="
echo ""

# Function to test if file exists
test_file() {
    local path=$1
    local description=$2
    
    if [ -f "$DOCS_DIR/$path" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description (missing: $path)"
        ((FAILED++))
        return 1
    fi
}

# Function to test if directory exists
test_dir() {
    local path=$1
    local description=$2
    
    if [ -d "$DOCS_DIR/$path" ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description (missing: $path)"
        ((FAILED++))
        return 1
    fi
}

echo "1. Testing Core Structure"
echo "-------------------------"
test_file "index.html" "Main index page"
test_file "404.html" "404 error page"
test_dir "assets" "Assets directory"
test_dir "en" "English docs"
echo ""

echo "2. Testing Main Sections"
echo "------------------------"
test_dir "decision-makers" "Decision Makers section"
test_dir "players" "Players section"
test_dir "managers" "Managers section"
test_dir "administrators" "Administrators section"
test_dir "developers" "Developers section"
test_dir "reference" "Reference section"
echo ""

echo "3. Testing Key Documentation Pages"
echo "-----------------------------------"
test_file "managers/tournament-management/index.html" "Tournament Management"
test_file "managers/league-management/index.html" "League Management"
test_file "administrators/scoreboard-autostart/index.html" "Scoreboard Autostart"
test_file "developers/developer-guide/index.html" "Developer Guide"
test_file "players/scoreboard-guide/index.html" "Scoreboard Guide"
echo ""

echo "4. Testing Multilingual Support"
echo "--------------------------------"
test_file "en/index.html" "English index"
test_file "en/managers/tournament-management/index.html" "English Tournament Management"
echo ""

echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Documentation is available at:"
    echo "  - /docs/index           (Main index)"
    echo "  - /docs/managers/tournament-management"
    echo "  - /docs/managers/league-management"
    echo ""
    echo "Rails documentation (Markdown with layout):"
    echo "  - /docs_page/index"
    echo "  - /docs_page/managers/tournament-management"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please rebuild documentation:${NC}"
    echo "  bundle exec rake mkdocs:deploy"
    exit 1
fi
