#!/bin/bash

# GitHub Access Setup Script for Carambus Scoreboard Pi
# Run this after adding the SSH key to GitHub

echo "🔑 Setting up GitHub access for scoreboard Pi..."

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

echo -e "\n${YELLOW}1. Testing SSH key setup...${NC}"

# Check if SSH key exists
if [ -f ~/.ssh/id_ed25519 ]; then
    print_status 0 "SSH key exists"
else
    print_status 1 "SSH key missing"
    exit 1
fi

# Start SSH agent
eval $(ssh-agent -s) > /dev/null 2>&1
ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1

echo -e "\n${YELLOW}2. Testing GitHub connection...${NC}"

# Test GitHub SSH connection
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    print_status 0 "GitHub SSH connection successful"
else
    print_status 1 "GitHub SSH connection failed"
    echo "Please ensure the SSH key has been added to GitHub:"
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYGHvUBCUBMgMbDkoPB3006jcA28kyQLV/kjm65X0OZ pi@192.168.178.53"
    exit 1
fi

echo -e "\n${YELLOW}3. Testing repository access...${NC}"

# Test repository access (replace with your actual repo URL)
REPO_URL="git@github.com:your-repo/carambus.git"

if git ls-remote $REPO_URL > /dev/null 2>&1; then
    print_status 0 "Repository access confirmed"
else
    print_status 1 "Repository access failed"
    echo "Please check the repository URL and permissions"
    exit 1
fi

echo -e "\n${YELLOW}4. Setting up Git configuration...${NC}"

# Configure Git
git config --global user.name "Carambus Scoreboard"
git config --global user.email "scoreboard@carambus.de"

print_status 0 "Git configuration complete"

echo -e "\n${GREEN}🎉 GitHub access setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Clone the repository: git clone $REPO_URL"
echo "2. Follow the FRESH_SD_TEST_CHECKLIST.md"
echo "3. Run the scoreboard setup"

echo -e "\n${YELLOW}Quick clone command:${NC}"
echo "cd /home/pi && git clone $REPO_URL carambus" 