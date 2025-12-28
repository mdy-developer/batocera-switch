#!/usr/bin/env bash

# BATOCERA.PRO INSTALLER
######################################################################
#---------------------------------------------------------------------
APPNAME="SWITCH-EMULATION FOR 41"
GITHUB_USER="mdy-developer"
GITHUB_REPO="batocera-switch"
ORIGIN="github.com/${GITHUB_USER}/${GITHUB_REPO}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
LOG_FILE="/tmp/${GITHUB_USER}-switch-installer-$(date +%Y%m%d_%H%M%S).log"
#---------------------------------------------------------------------
######################################################################

# --- Debug Mode ---
# Enable debug mode by setting DEBUG to true (e.g., DEBUG=true ./script.sh)
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# --- Logging ---
# Redirect all output to a log file and the console
exec &> >(tee -a "$LOG_FILE")

# --- Colors ---
X='\033[0m'       # reset
W='\033[0;37m'    # white
RED='\033[1;31m'  # red
BLUE='\033[1;34m' # blue
GREEN='\033[1;32m'# green
PURPLE='\033[1;35m'# purple

# --- Helper Functions ---

log() {
    local level="$1"
    local message="$2"
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [${level}] ${message}"
}

show_error() {
    log "ERROR" "$1"
    if command -v dialog &>/dev/null;
 then
        dialog --title "Error" --msgbox "$1" 8 60
    fi
    # Restore IPv6 before exiting
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    exit 1
}

download_file() {
    local dest_path="$1"
    local url_path="$2"
    local full_url="${BASE_URL}/${url_path}"
    
    log "INFO" "Downloading ${url_path}..."
    
    # Ensure destination directory exists
    mkdir -p "$(dirname "$dest_path")"
    
    if ! wget -q --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$dest_path" "$full_url"; then
        show_error "Failed to download file: ${full_url}"
    fi
}

# Function to compare semantic versions (e.g., 1.10.0 vs 1.2.0)
# Returns 0 if equal, 1 if version1 > version2, 2 if version2 > version1
compare_versions() {
    if [[ "$1" == "$2" ]]; then
        return 0
    fi
    local IFS=.
    # shellcheck disable=SC2206
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    return 0
}


check_config_version() {
    local cfg_path="/userdata/system/switch/CONFIG.txt"
    if [[ ! -f "$cfg_path" ]]; then
        return
    fi
    
    log "INFO" "Checking for new CONFIG.txt version..."
    local tmp_cfg="/tmp/.CONFIG.txt"
    
    download_file "$tmp_cfg" "system/switch/extra/batocera-switch-config.txt"
    
    local current_ver
    current_ver=$(grep "(ver " "$cfg_path" | head -n1 | sed 's,^.*(ver ,,g' | cut -d ")" -f1)
    [[ -z "$current_ver" ]] && current_ver="1.0.0"
    
    local latest_ver
    latest_ver=$(grep "(ver " "$tmp_cfg" | head -n1 | sed 's,^.*(ver ,,g' | cut -d ")" -f1)
    
    compare_versions "$latest_ver" "$current_ver"
    if [[ $? -eq 1 ]]; then
        log "INFO" "Updating CONFIG.txt to version ${latest_ver}"
        cp "$tmp_cfg" "$cfg_path"
    fi
    
    # Preserve user config for updater
    cp "$cfg_path" /tmp/.userconfigfile 2>/dev/null
}

# --- Main Installation Logic ---

main() {
    log "INFO" "Starting installer..."
    log "INFO" "Log file: $LOG_FILE"
    # --- Animated Intro ---
    for i in {1..5}; do
        clear
        echo
        log "INFO" "${G}- - - - - - - - -${X}"
        log "INFO" "${G}${APPNAME} INSTALLER${X}"
        log "INFO" "${G}- - - - - - - - -${X}"
        echo
        sleep 0.2
    done
    
    log "INFO" "${W}INSTALLING $APPNAME FOR BATOCERA${X}"
    log "INFO" "${W}USING $ORIGIN${X}"
    echo
    sleep 2
    
    # --- System Checks ---
    if ! uname -a | grep -q "x86_64"; then
        show_error "SYSTEM NOT SUPPORTED. You need Batocera x86_64."
    fi
    
    # Temporarily disable IPv6
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    
    log "INFO" "${PURPLE}PLEASE WAIT...${X}"
    
    # --- Config Preservation ---
    check_config_version

    # --- Purge Old Installs ---
    log "INFO" "${W}Removing old installation files...${X}"
    rm /userdata/system/switch/*.AppImage 2>/dev/null
    rm -rf /userdata/system/switch/{configgen,extra,logs,sudachi} 2>/dev/null
    rm "/userdata/system/switch/CONFIG.txt" 2>/dev/null
    rm /userdata/system/configs/emulationstation/{add_feat_switch.cfg,es_systems_switch.cfg,es_features_switch.cfg,es_features.cfg} 2>/dev/null
    rm "/userdata/roms/ports/Sudachi Qlauncher.sh" 2>/dev/null
    rm "/userdata/roms/ports/Sudachi Qlauncher.sh.keys" 2>/dev/null
    rm "/userdata/roms/ports/Switch Updater40.sh.keys" 2>/dev/null
    rm "/userdata/roms/ports/Switch Updater40.sh" 2>/dev/null
    rm /userdata/system/switch/extra/{suyu.png,suyu-config.desktop,batocera-config-suyu,batocera-config-suyuQL} 2>/dev/null
    rm /userdata/system/.local/share/applications/suyu-config.desktop 2>/dev/null
    rm "/userdata/roms/ports/Suyu Qlauncher.sh.keys" 2>/dev/null
    rm "/userdata/roms/ports/Suyu Qlauncher.sh" 2>/dev/null
    rm /userdata/system/configs/evmapy/switch.keys 2>/dev/null
    
    # --- Create Directory Structure ---
    log "INFO" "${W}Creating directory structure...${X}"
    mkdir -p /userdata/roms/switch /userdata/roms/ports/images \
             /userdata/bios/switch/firmware \
             /userdata/system/switch/extra \
             /userdata/system/switch/configgen/generators/{citron,yuzu,ryujinx,sudachi,eden} \
             /userdata/system/configs/evmapy \
             /userdata/system/configs/emulationstation

    # --- Download Files ---
    log "INFO" "${PURPLE}Downloading necessary files...${X}"
    
    # extra
    download_file "/userdata/system/switch/extra/batocera-config-ryujinx" "system/switch/extra/batocera-config-ryujinx"
    download_file "/userdata/system/switch/extra/batocera-config-ryujinx-avalonia" "system/switch/extra/batocera-config-ryujinx-avalonia"
    download_file "/userdata/system/switch/extra/batocera-config-sudachi" "system/switch/extra/batocera-config-sudachi"
    download_file "/userdata/system/switch/extra/batocera-config-sudachiQL" "system/switch/extra/batocera-config-sudachiQL"
    download_file "/userdata/system/switch/extra/batocera-config-yuzuEA" "system/switch/extra/batocera-config-yuzuEA"
    download_file "/userdata/system/switch/extra/batocera-switch-libselinux.so.1" "system/switch/extra/batocera-switch-libselinux.so.1"
    download_file "/userdata/system/switch/extra/batocera-switch-libthai.so.0.3" "system/switch/extra/batocera-switch-libthai.so.0.3"
    download_file "/userdata/system/switch/extra/batocera-switch-libtinfo.so.6" "system/switch/extra/batocera-switch-libtinfo.so.6"
    download_file "/userdata/system/switch/extra/batocera-switch-sshupdater.sh" "system/switch/extra/batocera-switch-sshupdater.sh"
    download_file "/userdata/system/switch/extra/batocera-switch-tar" "system/switch/extra/batocera-switch-tar"
    download_file "/userdata/system/switch/extra/batocera-switch-tput" "system/switch/extra/batocera-switch-tput"
    download_file "/userdata/system/switch/extra/batocera-switch-updater.sh" "system/switch/extra/batocera-switch-updater.sh"
    download_file "/userdata/system/switch/extra/icon_ryujinx.png" "system/switch/extra/icon_ryujinx.png"
    download_file "/userdata/system/switch/extra/icon_ryujinxg.png" "system/switch/extra/icon_ryujinxg.png"
    download_file "/userdata/system/switch/extra/libthai.so.0.3.1" "system/switch/extra/libthai.so.0.3.1"
    download_file "/userdata/system/switch/extra/ryujinx-avalonia.png" "system/switch/extra/ryujinx-avalonia.png"
    download_file "/userdata/system/switch/extra/ryujinx.png" "system/switch/extra/ryujinx.png"
    download_file "/userdata/system/switch/extra/yuzu.png" "system/switch/extra/yuzu.png"
    download_file "/userdata/system/switch/extra/yuzuEA.png" "system/switch/extra/yuzuEA.png"
    download_file "/userdata/system/switch/extra/sudachi.png" "system/switch/extra/sudachi.png"
    download_file "/userdata/system/switch/extra/citron.png" "system/switch/extra/citron.png"
    download_file "/userdata/system/switch/extra/batocera-config-citron" "system/switch/extra/batocera-config-citron"
    download_file "/userdata/system/switch/extra/eden.png" "system/switch/extra/eden.png"
    download_file "/userdata/system/switch/extra/batocera-config-eden" "system/switch/extra/batocera-config-eden"

    # config file
    download_file "/userdata/system/switch/CONFIG.txt" "system/switch/extra/batocera-switch-config.txt"
    
    # configgen
    download_file "/userdata/system/switch/configgen/generators/ryujinx/__init__.py" "system/switch/configgen/generators/ryujinx/__init__.py"
    download_file "/userdata/system/switch/configgen/generators/ryujinx/ryujinxMainlineGenerator.py" "system/switch/configgen/generators/ryujinx/ryujinxMainlineGenerator.py"
    download_file "/userdata/system/switch/configgen/generators/citron/citronGenerator.py" "system/switch/configgen/generators/citron/citronGenerator.py"
    download_file "/userdata/system/switch/configgen/generators/eden/edenGenerator.py" "system/switch/configgen/generators/eden/edenGenerator.py"
    download_file "/userdata/system/switch/configgen/generators/sudachi/sudachiGenerator.py" "system/switch/configgen/generators/sudachi/sudachiGenerator.py"
    download_file "/userdata/system/switch/configgen/generators/yuzu/__init__.py" "system/switch/configgen/generators/yuzu/__init__.py"
    download_file "/userdata/system/switch/configgen/generators/yuzu/yuzuMainlineGenerator.py" "system/switch/configgen/generators/yuzu/yuzuMainlineGenerator.py"
    download_file "/userdata/system/switch/configgen/generators/__init__.py" "system/switch/configgen/generators/__init__.py"
    download_file "/userdata/system/switch/configgen/generators/Generator.py" "system/switch/configgen/generators/Generator.py"
    download_file "/userdata/system/switch/configgen/GeneratorImporter.py" "system/switch/configgen/GeneratorImporter.py"
    download_file "/userdata/system/switch/configgen/switchlauncher.py" "system/switch/configgen/switchlauncher.py"
    download_file "/userdata/system/switch/configgen/configgen-defaults.yml" "system/switch/configgen/configgen-defaults.yml"
    download_file "/userdata/system/switch/configgen/configgen-defaults-arch.yml" "system/switch/configgen/configgen-defaults-arch.yml"
    download_file "/userdata/system/switch/configgen/Emulator.py" "system/switch/configgen/Emulator.py"
    download_file "/userdata/system/switch/configgen/batoceraFiles.py" "system/switch/configgen/batoceraFiles.py"
    download_file "/userdata/system/switch/configgen/controllersConfig.py" "system/switch/configgen/controllersConfig.py"
    download_file "/userdata/system/switch/configgen/evmapy.py" "system/switch/configgen/evmapy.py"
    
    # es config
    download_file "/userdata/system/configs/emulationstation/es_features_switch.cfg" "system/configs/emulationstation/es_features_switch.cfg"
    download_file "/userdata/system/configs/emulationstation/es_systems_switch.cfg" "system/configs/emulationstation/es_systems_switch.cfg"
    
    # evmapy
    download_file "/userdata/system/configs/evmapy/switch.keys" "system/configs/evmapy/switch.keys"

    # ports
    download_file "/userdata/roms/ports/Switch Updater.sh" "roms/ports/Switch Updater.sh"
    download_file "/userdata/roms/ports/Sudachi Qlauncher.sh" "roms/ports/Sudachi Qlauncher.sh"
    download_file "/userdata/roms/ports/Sudachi Qlauncher.sh.keys" "roms/ports/Sudachi Qlauncher.sh.keys"
    
    # port images
    download_file "/userdata/roms/ports/images/Switch Updater-boxart.png" "roms/ports/images/Switch Updater-boxart.png"
    download_file "/userdata/roms/ports/images/Switch Updater-cartridge.png" "roms/ports/images/Switch Updater-cartridge.png"
    download_file "/userdata/roms/ports/images/Switch Updater-mix.png" "roms/ports/images/Switch Updater-mix.png"
    download_file "/userdata/roms/ports/images/Switch Updater-screenshot.png" "roms/ports/images/Switch Updater-screenshot.png"
    download_file "/userdata/roms/ports/images/Switch Updater-wheel.png" "roms/ports/images/Switch Updater-wheel.png"
    
    # roms/bios info
    download_file "/userdata/roms/switch/_info.txt" "roms/switch/_info.txt"
    download_file "/userdata/bios/switch/_info.txt" "bios/switch/_info.txt"

    # --- Finalize ---
    log "INFO" "${W}Finalizing installation...${X}"
    rm /userdata/roms/ports/update{yuzu,yuzuea,yuzuEA,ryujinx,ryujinxavalonia}.sh 2>/dev/null
    
    dos2unix /userdata/system/switch/extra/*.sh 2>/dev/null
    dos2unix /userdata/system/switch/extra/batocera-config* 2>/dev/null
    chmod a+x /userdata/system/switch/extra/*.sh 2>/dev/null
    chmod a+x /userdata/system/switch/extra/batocera-config* 2>/dev/null
    chmod a+x /userdata/system/switch/extra/batocera-switch-lib* 2>/dev/null
    chmod a+x /userdata/system/switch/extra/*.desktop 2>/dev/null
    chmod a+x /userdata/system/.local/share/applications/*.desktop 2>/dev/null
    
    log "INFO" "${GREEN} > INSTALLATION COMPLETE${X}"
    sleep 1
    
    # --- Run Updater ---
    log "INFO" "${PURPLE}LOADING SWITCH UPDATER...${X}"
    local updater_script="/tmp/batocera-switch-updater.sh"
    download_file "$updater_script" "system/switch/extra/batocera-switch-updater.sh"
    sed -i 's,MODE=DISPLAY,MODE=CONSOLE,g' "$updater_script" 2>/dev/null
    dos2unix "$updater_script" 2>/dev/null
    chmod a+x "$updater_script" 2>/dev/null
    
    if bash "$updater_script" CONSOLE; then
        touch /userdata/system/switch/extra/installation
    fi
    
    # Restore user config if it was preserved
    if [[ -e /tmp/.userconfigfile ]]; then
        cp /tmp/.userconfigfile /userdata/system/switch/CONFIG.txt 2>/dev/null
    fi
}

# --- Post-Installation ---

post_install_messages() {
    if [[ -e /userdata/system/switch/extra/installation ]]; then
        rm /userdata/system/switch/extra/installation 2>/dev/null
        clear
        log "INFO" "   ${BLUE}INSTALLER BY ${GREEN}MDY-DEVELOPER${X}"
        log "INFO" "   ${GREEN}${APPNAME} INSTALLED${X}"
        echo
        log "INFO" "   ${PURPLE}IMPORTANT INFORMATION!${X}"
        log "INFO" "   - Your userdata partition MUST be EXT4 or BTRFS."
        log "INFO" "   - Place your 'prod.keys' and 'title.keys' into /userdata/bios/switch/"
        log "INFO" "   - Place your firmware *.nca files into /userdata/bios/switch/firmware/"
        echo
        log "INFO" "   ${RED}IN CASE OF CONTROLLER ISSUES:${X}"
        log "INFO" "   - Set 'autocontroller = off' in advanced settings and configure manually in F1 applications."
        echo
        log "INFO" "   ${GREEN}RELOAD YOUR GAMELIST AND ENJOY${X}"
        echo
        log "INFO" "   This page will automatically close in 10 seconds..."
        sleep 10
        curl -s http://127.0.0.1:1234/reloadgames > /dev/null
        exit 0
    else
        clear
        show_error "Looks like the installation failed :("
        log "INFO" "   Try running the script again."
        log "INFO" "   If it still fails, try: cd /userdata ; wget -O s batocera.pro/s ; chmod 777 s ; ./s"
        echo
        sleep 5
        exit 1
    fi
}

# --- Script Entry Point ---

# Ensure we have a clean exit
trap 'sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null; sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null' EXIT

main
post_install_messages