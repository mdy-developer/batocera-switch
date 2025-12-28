#!/bin/bash

# --- Configuration ---
GITHUB_USER="mdy-developer"
GITHUB_REPO="batocera-switch"
INSTALLER_NAME="[${GITHUB_USER} Switch Installer]"
LOG_FILE="/tmp/${GITHUB_USER}-switch-installer-$(date +%Y%m%d_%H%M%S).log"

# --- Debug Mode ---
# Enable debug mode by setting DEBUG to true (e.g., DEBUG=true ./script.sh)
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# --- Logging ---
# Redirect all output to a log file and the console
exec &> >(tee -a "$LOG_FILE")

# --- Functions ---
log() {
    local level="$1"
    local message="$2"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] $INSTALLER_NAME: $message"
}

show_error() {
    log "ERROR" "$1"
    if command -v dialog &> /dev/null; then
        dialog --msgbox "$1" 8 60
        clear
    fi
    exit 1
}

# --- Main Script ---
log "INFO" "Starting installer..."
log "INFO" "Log file: $LOG_FILE"

log "INFO" "Detecting Batocera version..."

# Get the main version of Batocera
version=$(batocera-es-swissknife --version | grep -oE '^[0-9]+')

# Check that the version is a number
if [[ -z "$version" ]]; then
    show_error "Could not detect a valid Batocera version. Installation canceled."
fi

log "INFO" "Detected Batocera version: $version"
sleep 2

# Determine the correct installer script based on the version
case $version in
    39|40)
        branch="main"
        script_name="batocera-switch-installer-v40.sh"
        ;;
    41)
        branch="main"
        script_name="batocera-switch-installer.sh"
        ;;
    42|43|44)
        branch="42"
        script_name="batocera-switch-installer.sh"
        ;;
    *)
        show_error "Unsupported Batocera version: $version. Installation canceled."
        ;;
esac

# Construct the download URL
installer_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/refs/heads/${branch}/system/switch/extra/${script_name}"

log "INFO" "Starting script for Batocera $version..."
log "INFO" "Downloading installer from: $installer_url"
sleep 3

# Download and execute the installer
temp_script=$(mktemp)
if curl -fsSL "$installer_url" -o "$temp_script"; then
    log "INFO" "Installer downloaded successfully. Executing..."
    chmod +x "$temp_script"
    bash "$temp_script"
    rm "$temp_script"
    log "INFO" "Installer script finished."
else
    rm "$temp_script"
    show_error "Failed to download the installer script. Please check your internet connection."
fi

log "INFO" "Installation process finished."
