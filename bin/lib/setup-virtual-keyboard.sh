#!/bin/bash
# Setup Virtual Keyboard (matchbox-keyboard) on Raspberry Pi
# This script installs and configures matchbox-keyboard for use in kiosk mode
#
# Usage: setup-virtual-keyboard.sh <ssh_user> <ssh_port> <remote_ip>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Parse arguments
if [ $# -lt 3 ]; then
    error "Missing required arguments"
    echo "Usage: $0 <ssh_user> <ssh_port> <remote_ip>"
    exit 1
fi

SSH_USER="$1"
SSH_PORT="$2"
REMOTE_IP="$3"

log "⌨️  Setting up Virtual Keyboard"
log "=============================="

# Step 1: Install matchbox-keyboard
info "Installing matchbox-keyboard..."
INSTALL_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "sudo apt-get update -qq 2>&1 && sudo apt-get install -y matchbox-keyboard 2>&1" 2>&1 || echo "INSTALL_FAILED")

if echo "$INSTALL_OUTPUT" | grep -qE "(upgraded|installed|already|Setting up|Unpacking)" 2>/dev/null; then
    log "✅ matchbox-keyboard installed or already present"
elif echo "$INSTALL_OUTPUT" | grep -qE "(Unable to locate|E: Package|not found|E: Unable)" 2>/dev/null; then
    warning "matchbox-keyboard package not found in repository"
    warning "This package may not be available for your Raspberry Pi OS version"
    warning "You may need to install it manually or use an alternative virtual keyboard"
else
    warning "matchbox-keyboard installation status unclear"
    warning "Verification will check if it's available"
fi

# Step 2: Create toggle script
info "Creating keyboard toggle script..."
TOGGLE_SCRIPT="#!/bin/bash
# Toggle matchbox-keyboard on/off
# Usage: toggle-keyboard.sh

export DISPLAY=:0

# Find X authority
for auth_file in /home/$SSH_USER/.Xauthority /home/*/.Xauthority /run/user/*/gdm/Xauthority /run/user/1000/.Xauthority; do
    if [ -f \"\$auth_file\" ]; then
        export XAUTHORITY=\"\$auth_file\"
        break
    fi
done

xhost +local: 2>/dev/null || true

# Check if keyboard is running
PID=\$(pidof matchbox-keyboard 2>/dev/null || echo \"\")

if [ -n \"\$PID\" ]; then
    # Keyboard is running - kill it
    kill \"\$PID\" 2>/dev/null || true
    echo \"Virtual keyboard closed\"
    exit 0
else
    # Keyboard is not running - start it
    matchbox-keyboard &
    echo \"Virtual keyboard opened\"
    exit 0
fi
"

echo "$TOGGLE_SCRIPT" | ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "cat > /tmp/toggle-keyboard.sh" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "sudo mv /tmp/toggle-keyboard.sh /usr/local/bin/toggle-keyboard.sh && sudo chmod +x /usr/local/bin/toggle-keyboard.sh" 2>/dev/null
log "✅ Toggle script created at /usr/local/bin/toggle-keyboard.sh"

# Step 3: Create desktop entry (optional, for desktop environments)
info "Creating desktop entry (if desktop environment exists)..."
DESKTOP_ENTRY="[Desktop Entry]
Name=Toggle Virtual Keyboard
Comment=Show/hide on-screen keyboard
Exec=/usr/local/bin/toggle-keyboard.sh
Icon=keyboard
Terminal=false
Type=Application
Categories=Accessibility;Utility;
"

# Try to create desktop entry in common locations
DESKTOP_DIRS=(
    "/usr/share/raspi-ui-overrides/applications"
    "/home/$SSH_USER/.local/share/applications"
    "/usr/share/applications"
)

DESKTOP_CREATED=false
for DESKTOP_DIR in "${DESKTOP_DIRS[@]}"; do
    if ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "test -d '$DESKTOP_DIR' 2>/dev/null" 2>/dev/null; then
        echo "$DESKTOP_ENTRY" | ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "cat > /tmp/toggle-keyboard.desktop" 2>/dev/null
        
        if [ "$DESKTOP_DIR" = "/home/$SSH_USER/.local/share/applications" ]; then
            ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "mkdir -p '$DESKTOP_DIR' && mv /tmp/toggle-keyboard.desktop '$DESKTOP_DIR/toggle-keyboard.desktop' && chmod 644 '$DESKTOP_DIR/toggle-keyboard.desktop'" 2>/dev/null
        else
            ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "sudo mkdir -p '$DESKTOP_DIR' && sudo mv /tmp/toggle-keyboard.desktop '$DESKTOP_DIR/toggle-keyboard.desktop' && sudo chmod 644 '$DESKTOP_DIR/toggle-keyboard.desktop'" 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            log "✅ Desktop entry created in $DESKTOP_DIR"
            DESKTOP_CREATED=true
            break
        fi
    fi
done

if [ "$DESKTOP_CREATED" = false ]; then
    warning "Desktop entry not created (no desktop environment detected or permissions issue)"
    info "Toggle script is still available at /usr/local/bin/toggle-keyboard.sh"
fi

# Step 4: Test keyboard installation
info "Verifying keyboard installation..."
if ssh -p "$SSH_PORT" "$SSH_USER@$REMOTE_IP" "command -v matchbox-keyboard >/dev/null 2>&1" 2>/dev/null; then
    log "✅ matchbox-keyboard is available"
    KEYBOARD_AVAILABLE=true
else
    warning "matchbox-keyboard not found in PATH"
    warning "This may be because:"
    warning "  - matchbox-keyboard is not available in your Raspberry Pi OS repository"
    warning "  - Installation failed silently"
    warning "  - The package needs to be installed manually"
    info ""
    info "The toggle script has been created and will work once matchbox-keyboard is installed."
    info "To install manually, try:"
    echo "  ssh -p $SSH_PORT $SSH_USER@$REMOTE_IP 'sudo apt-get update && sudo apt-get install matchbox-keyboard'"
    KEYBOARD_AVAILABLE=false
fi

if [ "$KEYBOARD_AVAILABLE" = true ]; then
    log "✅ Virtual keyboard setup complete"
else
    log "⚠️  Virtual keyboard setup partially complete (toggle script ready, keyboard package missing)"
fi
log ""
info "Usage:"
echo "  To toggle keyboard: ssh -p $SSH_PORT $SSH_USER@$REMOTE_IP '/usr/local/bin/toggle-keyboard.sh'"
echo "  Or run locally on Pi: toggle-keyboard.sh"
echo ""
info "Note: The keyboard can be toggled on/off using the toggle script."
info "      It will not auto-start - use the toggle script when needed."

