#!/usr/bin/env bash
################################################################################
# v3.3                SWITCH EMULATORS UPDATER FOR BATOCERA                    #
#                   ----------------------------------------                   #
#                     > github.com/mdy-developer/batocera-switch                   #
#                                                                              #     
################################################################################

# --- Configuration ---
GITHUB_USER="mdy-developer"
GITHUB_REPO="batocera-switch"
ORIGIN="github.com/${GITHUB_USER}/${GITHUB_REPO}"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main"
LOG_FILE="/tmp/${GITHUB_USER}-switch-updater-$(date +%Y%m%d_%H%M%S).log"
# Default emulator settings - can be overridden by CONFIG.txt
EMULATORS_DEFAULT="YUZUEA RYUJINX RYUJINXAVALONIA" 
MODE_DEFAULT="DISPLAY"
UPDATES_LOCKED_DEFAULT="UNLOCKED" # Changed from UPDATES_DEFAULT to UPDATES_LOCKED_DEFAULT for clarity
TEXT_SIZE_DEFAULT="AUTO"
TEXT_COLOR_DEFAULT="WHITE"
THEME_COLOR_DEFAULT="WHITE"
THEME_COLOR_OK_DEFAULT="WHITE"
THEME_COLOR_YUZUEA_DEFAULT="RED"
THEME_COLOR_RYUJINX_DEFAULT="BLUE"
THEME_COLOR_RYUJINXAVALONIA_DEFAULT="BLUE"
ANIMATION_DEFAULT="NO"

# --- Debug Mode ---
# Enable debug mode by setting DEBUG to true (e.g., DEBUG=true ./script.sh)
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# --- Logging ---
# Redirect all output to a log file and the console
exec &> >(tee -a "$LOG_FILE")

# --- Colors ---
# Define colors here, will be parsed later from config
X='\033[0m'       # reset
W='\033[0;37m'    # white
RED='\033[1;31m'  # red
BLUE='\033[1;34m' # blue
GREEN='\033[1;32m'# green
YELLOW='\033[1;33m' # yellow
PURPLE='\033[1;35m'# purple
CYAN='\033[1;36m' # cyan
DARKRED='\033[0;31m' # darkred
DARKBLUE='\033[0;34m'# darkblue
DARKGREEN='\033[0;32m'# darkgreen
DARKYELLOW='\033[0;33m' # darkyellow
DARKPURPLE='\033[0;35m'# darkpurple
DARKCYAN='\033[0;36m' # darkcyan
BLACK='\033[0;30m' # black


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

download_file_github() {
    local dest_path="$1"
    local url_path="$2" # Path relative to BASE_URL
    local full_url="${BASE_URL}/${url_path}"
    
    log "INFO" "Downloading ${url_path} to ${dest_path}..."
    
    mkdir -p "$(dirname "$dest_path")" || show_error "Failed to create directory for $dest_path"
    
    if ! wget -q --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$dest_path" "$full_url"; then
        show_error "Failed to download file from GitHub: ${full_url}"
    fi
}

download_file_fallback() {
    local dest_path="$1"
    local full_url="$2" # Full URL including host
    
    log "INFO" "Downloading ${full_url} (fallback) to ${dest_path}..."
    
    mkdir -p "$(dirname "$dest_path")" || show_error "Failed to create directory for $dest_path"
    
    if ! wget -q --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$dest_path" "$full_url"; then
        show_error "Failed to download file from fallback server: ${full_url}"
    fi
}

check_internet() {
    log "INFO" "Checking internet connection..."
    # Check using curl
    if curl -s --max-time 2 -I http://github.com | grep -q "HTTP/[12].[01] [23].."; then
        log "INFO" "Internet connection via curl: OK"
        return 0
    fi 
    
    # Check using ping
    if ping -q -w 1 -c 1 github.com > /dev/null;
 then
        log "INFO" "Internet connection via ping: OK"
        return 0
    fi

    # Check using wget
    if wget -q --spider http://github.com;
 then
        log "INFO" "Internet connection via wget: OK"
        return 0
    fi

    # If all methods fail, report no connectivity
    log "ERROR" "No internet connection detected."
    return 1
}

# Function to compare semantic versions (e.g., 1.10.0 vs 1.2.0)
# Returns 0 if equal, 1 if version1 > version2, 2 if version2 > version1
compare_versions() {
    if [[ "$1" == "$2" ]]; then
        return 0
    fi
    local IFS=. # shellcheck disable=SC2034
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

parse_colors() {
    # Dynamically assign ANSI color codes based on config (or defaults)
    # Use indirect expansion to get the value of the color variable (e.g. $RED) 
    TEXT_COLOR_VAL="${!TEXT_COLOR}" 
    THEME_COLOR_VAL="${!THEME_COLOR}"
    THEME_COLOR_OK_VAL="${!THEME_COLOR_OK}"
    THEME_COLOR_YUZUEA_VAL="${!THEME_COLOR_YUZUEA}"
    THEME_COLOR_RYUJINX_VAL="${!THEME_COLOR_RYUJINX}"
    THEME_COLOR_RYUJINXAVALONIA_VAL="${!THEME_COLOR_RYUJINXAVALONIA}"

    # Override colors for CONSOLE mode if applicable
    if [[ "$MODE" = "CONSOLE" ]]; then 
        TEXT_COLOR_VAL=$X 
        THEME_COLOR_VAL=$X
        THEME_COLOR_OK_VAL=$X
        THEME_COLOR_YUZUEA_VAL=$X
        THEME_COLOR_RYUJINX_VAL=$X
        THEME_COLOR_RYUJINXAVALONIA_VAL=$X
    fi
}

generate_shortcut_launcher() { 
    local Name="$1"
    local name_lower="$2" # lowercase name
    local extra_path="$extra" # Assuming $extra is defined globally
    local shortcut_file="${extra_path}/${Name}.desktop"

    log "INFO" "Generating shortcut for $Name..."
    rm -f "$shortcut_file" 
    
    {
        echo "[Desktop Entry]"
        echo "Version=1.0"
        case "$Name" in
            eden)
                echo "Icon=${extra_path}/eden.png"
                echo "Exec=${extra_path}/batocera-config-eden"
                echo "Name=Eden-config"
                ;;;
            citron)
                echo "Icon=${extra_path}/citron.png"
                echo "Exec=${extra_path}/batocera-config-citron"
                echo "Name=Citron-config"
                ;;;
            sudachi)
                echo "Icon=${extra_path}/sudachi.png"
                echo "Exec=${extra_path}/batocera-config-sudachi"
                echo "Name=Sudachi-config"
                ;;;
            Ryujinx)
                echo "Icon=${extra_path}/icon_ryujinxg.png"
                echo "Exec=/userdata/system/switch/Ryujinx.AppImage"
                echo "Name=Ryujinx-config"
                ;;;
            "Ryujinx-Avalonia")
                echo "Icon=${extra_path}/icon_ryujinx.png"
                echo "Exec=/userdata/system/switch/Ryujinx-Avalonia.AppImage"
                echo "Name=Ryujinx-Avalonia-config"
                ;;;
            yuzuEA)
                echo "Icon=${extra_path}/yuzuEA.png"
                echo "Exec=/userdata/system/switch/yuzuEA.AppImage"
                echo "Name=YuzuEA-config"
                ;;;
            *)
                log "WARN" "Unknown emulator $Name for shortcut generation."
                echo "Icon=${extra_path}/icon_loading.png" # Fallback icon
                echo "Exec=/usr/bin/echo \"No launcher defined for $Name\""
                echo "Name=${Name}-config"
                ;;;
        esac
        echo "Terminal=false"
        echo "Type=Application"
        echo "Categories=Game;batocera.linux;"
    } >> "$shortcut_file" 
    
    dos2unix "$shortcut_file" &>/dev/null
    chmod a+x "$shortcut_file" &>/dev/null
} 

clear_old_desktop_shortcuts() {
    log "INFO" "Removing old desktop shortcuts..."
    local apps_dir="/userdata/system/.local/share/applications"
    local usr_apps_dir="/usr/share/applications"

    # Define common patterns for old desktop files
    local old_desktop_patterns="eden-config.desktop yuzu-config.desktop yuzuEA-config.desktop citron-config.desktop sudachi-config.desktop ryujinx-config.desktop Ryujinx-config.desktop ryujinxavalonia-config.desktop Ryujinx-Avalonia-config.desktop ryujinxldn-config.desktop"

    for pattern in $old_desktop_patterns; do
        rm -f "${apps_dir}/${pattern}" &>/dev/null
        rm -f "${usr_apps_dir}/${pattern}" &>/dev/null
    done
}

# --- EMULATOR SPECIFIC UPDATE FUNCTIONS (Refactored from original update_emulator) ---

update_emulator_yuzuea() {
    log "INFO" "Attempting to update YUZUEA..."
    local yuzuea_appimage_path="${extra}/appimages/yuzuea4176.AppImage"
    local yuzuea_dest_path="/userdata/system/switch/yuzuEA.AppImage"
    local yuzuea_version="4176"
    local yuzuea_checksum="9f20b0e6bacd2eb9723637d078d463eb"
    local yuzuea_fallback_url="https://foclabroc.freeboxos.fr:55973/share/6_FB-NuZriqYuHKt/yuzuea4176.AppImage"

    # Try to download from fallback first as original script seemed to prefer specific version
    download_file_fallback "$yuzuea_appimage_path" "$yuzuea_fallback_url"
    cp "$yuzuea_appimage_path" "$yuzuea_dest_path" || show_error "Failed to copy YuzuEA AppImage."

    if [[ -f "$yuzuea_dest_path" ]]; then	
        local checksum_file=$(md5sum "$yuzuea_dest_path" | awk '{print $1}')
        if [[ "$checksum_file" != "$yuzuea_checksum" ]]; then 
            log "WARN" "YUZU-EA AppImage checksum mismatch. Attempting re-download from fallback."
            rm -f "$yuzuea_appimage_path"
            download_file_fallback "$yuzuea_appimage_path" "$yuzuea_fallback_url"
            cp "$yuzuea_appimage_path" "$yuzuea_dest_path" || show_error "Failed to copy YuzuEA AppImage after re-download."
            # Check checksum again after re-download
            checksum_file=$(md5sum "$yuzuea_dest_path" | awk '{print $1}')
            if [[ "$checksum_file" != "$yuzuea_checksum" ]]; then
                show_error "YUZU-EA download fail. Please put yuzuea4176.AppImage in /userdata/system/switch/appimages manually then relaunch script."	    
            fi
        fi
        log "INFO" "YUZU-EA   ${THEME_COLOR_OK_VAL}❯❯   /V${yuzuea_version}/ ${GREEN}SUCCESS${X}"
        
        # Extract and copy libraries
        local extract_dir="${temp_dir}/yuzuea_extract"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        mv "$yuzuea_dest_path" "${extract_dir}/yuzuEA.AppImage" || show_error "Failed to move YuzuEA AppImage for extraction."
        chmod a+x "${extract_dir}/yuzuEA.AppImage" || show_error "Failed to make YuzuEA AppImage executable."
        "${extract_dir}/yuzuEA.AppImage" --appimage-extract &>/dev/null || log "WARN" "Failed to extract YuzuEA AppImage."
        
        local yuzu_extra_lib_path="${extra}/yuzuea"
        mkdir -p "$yuzu_extra_lib_path"

        cp "${extract_dir}/squashfs-root/usr/lib/libQt5"* "${yuzu_extra_lib_path}/" 2>/dev/null
        cp "${extract_dir}/squashfs-root/usr/lib/libcrypto"* "${yuzu_extra_lib_path}/" 2>/dev/null
        cp "${extract_dir}/squashfs-root/usr/lib/libssl"* "${yuzu_extra_lib_path}/" 2>/dev/null
        cp "${extract_dir}/squashfs-root/usr/lib/libicu"* "${yuzu_extra_lib_path}/" 2>/dev/null
        cp "${extract_dir}/squashfs-root/usr/bin/yuzu" "${yuzu_extra_lib_path}/yuzu" 2>/dev/null
        cp "${extract_dir}/squashfs-root/usr/bin/yuzu-room" "${yuzu_extra_lib_path}/yuzu-room" 2>/dev/null
        
        # Fix broken libstdc++.so.6 for v37 
        if [[ "$(uname -a | awk '{print $3}')" > "6.2" ]]; then 
            download_file_github "${yuzu_extra_lib_path}/libstdc++.so.6" "system/switch/extra/batocera-switch-libstdc++.so.6"
        else 
            rm -f "${yuzu_extra_lib_path}/libstdc++.so.6" 2>/dev/null
        fi
        
        # Add yuzu's bundled 'optional' libs 
        cp "${extract_dir}/squashfs-root/usr/optional/libstdc++/libstdc++.so.6" "${yuzu_extra_lib_path}/libstdc++.so.6"
        cp "${extract_dir}/squashfs-root/usr/optional/libgcc_s/libgcc_s.so.1" "${yuzu_extra_lib_path}/libgcc_s.so.1"
        cp "${extract_dir}/squashfs-root/usr/optional/exec.so" "${yuzu_extra_lib_path}/exec.so"
        chmod a+x "${yuzu_extra_lib_path}/lib"* 2>/dev/null

        # Make launcher script for YuzuEA
        local launcher_script="/userdata/system/switch/yuzuEA.AppImage"
        rm -f "$launcher_script"
        {
            echo '#!/bin/bash'
            echo 'export XDG_MENU_PREFIX=batocera-'
            echo 'export XDG_CONFIG_DIRS=/etc/xdg'
            echo 'export XDG_CURRENT_DESKTOP=XFCE'
            echo 'export DESKTOP_SESSION=XFCE'
            echo '/userdata/system/switch/extra/batocera-switch-mousemove.sh &'
            echo '/userdata/system/switch/extra/batocera-sync-firmware.sh'
            echo 'if [ ! -L /userdata/system/configs/Ryujinx/bis/user/save ]; then mkdir -p /userdata/system/configs/Ryujinx/bis/user/save 2>/dev/null; rsync -au /userdata/saves/Ryujinx/ /userdata/system/configs/Ryujinx/bis/user/save/ 2>/dev/null; fi'
            echo 'if [ ! -L /userdata/system/configs/yuzu/nand/user/save ]; then mkdir -p /userdata/system/configs/yuzu/nand/user/save 2>/dev/null; rsync -au /userdata/saves/yuzu/ /userdata/system/configs/yuzu/nand/user/save/ 2>/dev/null; fi'
            echo 'mkdir -p /userdata/system/configs/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/yuzu/keys/ 2>/dev/null '
            echo 'mkdir -p /userdata/system/.local/share/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/.local/share/yuzu/keys/ 2>/dev/null '
            echo 'mkdir -p /userdata/system/configs/Ryujinx/system 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/Ryujinx/system/ 2>/dev/null '
            echo 'rm -f /usr/bin/yuzu 2>/dev/null; rm -f /usr/bin/yuzu-room 2>/dev/null'
            echo 'ln -s /userdata/system/switch/yuzuEA.AppImage /usr/bin/yuzu 2>/dev/null'
            echo 'cp /userdata/system/switch/extra/yuzuea/yuzu-room /usr/bin/yuzu-room 2>/dev/null'
            echo 'mkdir -p /userdata/system/switch/logs 2>/dev/null '
            echo 'log1=/userdata/system/switch/logs/yuzuEA-out.txt 2>/dev/null '
            echo 'log2=/userdata/system/switch/logs/yuzuEA-err.txt 2>/dev/null '
            echo 'rm -f "$log1" 2>/dev/null && rm -f "$log2" 2>/dev/null '
            echo 'ulimit -H -n 819200; ulimit -S -n 819200; ulimit -S -n 819200 yuzu;'
            echo 'rom="$(echo "$@" | sed '\''s,-f -g ,,g'\'')" ' 
            echo 'if [[ "$rom" = "" ]]; then ' 
            echo '  DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 LC_ALL=C NO_AT_BRIDGE=1 QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 LD_LIBRARY_PATH="/userdata/system/switch/extra/yuzuea:${LD_LIBRARY_PATH}" QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb /userdata/system/switch/extra/yuzuea/yuzu -f -g > >(tee "$log1") 2> >(tee "$log2" >&2) ' 
            echo 'else ' 
            echo '  rm -f /tmp/switchromname 2>/dev/null ' 
            echo '    echo "$rom" >> /tmp/switchromname 2>/dev/null ' 
            echo '      /userdata/system/switch/extra/batocera-switch-nsz-converter.sh ' 
            echo '    rom="$(cat /tmp/switchromname)" ' 
            echo '  fs=$( blkid | grep "$(df -h /userdata | awk '\''END {print $1}'\'' )" | sed '\''s,^.*TYPE=,,g'\'') | sed '\''s,",,,g'\'') | tr '\''a-z\'' '\''A-Z'\'') ' 
            echo '  if [[ "$fs" == *"EXT"* ]] || [[ "$fs" == *"BTR"* ]]; then ' 
            echo '    rm -f /tmp/yuzurom 2>/dev/null; ln -sf "$rom" "/tmp/yuzurom"; ROM="/tmp/yuzurom"; ' 
            echo '    DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb LC_ALL=C.utf8 NO_AT_BRIDGE=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 LD_LIBRARY_PATH="/userdata/system/switch/extra/yuzuea:${LD_LIBRARY_PATH}" QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb /userdata/system/switch/extra/yuzuea/yuzu -f -g "$ROM" 1>"$log1" 2>"$log2" ' 
            echo '  else ' 
            echo '    ROM="$rom" ' 
            echo '    DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb LC_ALL=C.utf8 NO_AT_BRIDGE=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 LD_LIBRARY_PATH="/userdata/system/switch/extra/yuzuea:${LD_LIBRARY_PATH}" QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb /userdata/system/switch/extra/yuzuea/yuzu -f -g "$ROM" 1>"$log1" 2>"$log2" ' 
            echo '  fi ' 
            echo 'fi' 
        } >> "$launcher_script" 
        
        dos2unix "$launcher_script" &>/dev/null
        chmod a+x "$launcher_script" &>/dev/null
        chmod a+x "${yuzu_extra_lib_path}/yuzu" &>/dev/null
        chmod a+x "${yuzu_extra_lib_path}/yuzu-room" &>/dev/null
        
        # Send version to cookie
        rm -f "${extra}/yuzuea/version.txt" 2>/dev/null
        echo "$yuzuea_version" >> "${extra}/yuzuea/version.txt"
    else
        log "ERROR" "YUZU-EA AppImage not found or invalid after download."
    fi
}

update_emulator_ryujinx() {
    log "INFO" "Attempting to update RYUJINX..."
    local ryujinx_version="1.3.3"
    local ryujinx_download_url="https://git.ryujinx.app/api/v4/projects/1/packages/generic/Ryubing/1.3.3/ryujinx-1.3.3-linux_x64.tar.gz"
    local ryujinx_tarball_path="/userdata/system/switch/ryujinx-${ryujinx_version}-linux_x64.tar.gz"
    local ryujinx_fallback_url="https://foclabroc.freeboxos.fr:55973/share/0A4ENRF8IO0_9nzt/ryujinx-canary-1.3.138-linux_x64.tar.gz" # Original fallback for Canary 1.3.138
    local ryujinx_fallback_tarball_path="${extra}/appimages/ryujinx-canary-1.3.138-linux_x64.tar.gz"

    # Always try direct download first as per user's request for specific version
    if ! wget -q --show-progress --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$ryujinx_tarball_path" "$ryujinx_download_url"; then
        log "WARN" "Failed to download specified Ryujinx ${ryujinx_version}. Attempting fallback to ${ryujinx_fallback_url}."
        # If download of specific version fails, try the original fallback (Canary 1.3.138)
        download_file_fallback "$ryujinx_fallback_tarball_path" "$ryujinx_fallback_url"
        cp "$ryujinx_fallback_tarball_path" "$ryujinx_tarball_path" || show_error "Failed to copy Ryujinx fallback tarball."
        # Update version to fallback version if fallback was used
        if [[ -f "$ryujinx_tarball_path" ]] && [[ "$(md5sum "$ryujinx_tarball_path" | awk '{print $1}')" != "d7a8d5f4e6c3b2a1f0e9d8c7b6a5e4d3" ]]; then # Placeholder checksum for 1.3.138 if needed
            log "WARN" "Ryujinx fallback download might be corrupted or incorrect version."
        fi
        ryujinx_version="1.3.138" # Set version to fallback version if fallback was successful
    fi
    
    local link_ryujinx="${ryujinx_tarball_path}"
    if [[ -f "$link_ryujinx" ]] && [[ $(stat -c%s "$link_ryujinx") -gt 2048 ]]; then
        log "INFO" "RYUJINX   ${THEME_COLOR_OK_VAL}❯❯   /V${ryujinx_version}/ ${GREEN}SUCCESS${X}"

        # Get dependencies for handling ryujinx (these are shared links)
        local link_tar_gh="system/switch/extra/batocera-switch-tar"
        local link_libselinux_gh="system/switch/extra/batocera-switch-libselinux.so.1"
        
        # Tar utility
        if [[ ! -e "${extra}/batocera-switch-tar" ]]; then 
            download_file_github "${extra}/batocera-switch-tar" "$link_tar_gh"
            chmod a+x "${extra}/batocera-switch-tar"
        fi
        
        # libselinux
        if [[ ! -e "/usr/lib/libselinux.so.1" ]]; then
            download_file_github "${extra}/batocera-switch-libselinux.so.1" "$link_libselinux_gh"
            if [[ -f "${extra}/batocera-switch-libselinux.so.1" ]] && [[ "$(wc -c "${extra}/batocera-switch-libselinux.so.1" | awk '{print $1}')" -lt "100" ]]; then 
                log "WARN" "Downloaded libselinux.so.1 appears to be too small, re-downloading."
                download_file_github "${extra}/batocera-switch-libselinux.so.1" "$link_libselinux_gh"   
            fi
            chmod a+x "${extra}/batocera-switch-libselinux.so.1"
            cp "${extra}/batocera-switch-libselinux.so.1" "/usr/lib/libselinux.so.1" 2>/dev/null
        fi
        if [[ -e "${extra}/batocera-switch-libselinux.so.1" ]]; then 
           cp "${extra}/batocera-switch-libselinux.so.1" "${extra}/libselinux.so.1" 2>/dev/null # Redundant copy to extra? Original script did this.
        fi

        local emu="ryujinx"
        mkdir -p "${extra}/$emu"
        rm -rf "${temp_dir}/$emu"
        mkdir -p "${temp_dir}/$emu"
        
        mv "$link_ryujinx" "${temp_dir}/$emu/ryujinx-${ryujinx_version}-linux_x64.tar.gz" || show_error "Failed to move Ryujinx tarball for extraction."
        
        download_file_github "${extra}/$emu/xdg-mime" "system/switch/extra/xdg-mime"
        chmod a+x "${extra}/$emu/xdg-mime"

        LD_LIBRARY_PATH="${extra}:/usr/lib64:/usr/lib:/lib:${LD_LIBRARY_PATH}" "${extra}/batocera-switch-tar" -xf "${temp_dir}/$emu/ryujinx-${ryujinx_version}-linux_x64.tar.gz" -C "${temp_dir}/$emu" || show_error "Failed to extract Ryujinx tarball."
        
        # Copy extracted files
        cp -rL "${temp_dir}/$emu/publish/mime/"* "${extra}/$emu/mime/" 2>/dev/null
        cp -rL "${temp_dir}/$emu/publish/"*.config "${extra}/$emu/" 2>/dev/null
        cp -rL "${temp_dir}/$emu/publish/lib"* "${extra}/$emu/" 2>/dev/null
        
        # Create startup script for Ryujinx (originally inside a temp file and sourced)
        local ryujinx_startup_script="${extra}/${emu}/startup"
        rm -f "$ryujinx_startup_script"
        {
            echo '#!/bin/bash'
            echo "cp ${extra}/$emu/lib* /lib/ 2>/dev/null"
        } >> "$ryujinx_startup_script"
        dos2unix "$ryujinx_startup_script" &>/dev/null
        chmod a+x "$ryujinx_startup_script" &>/dev/null
        "$ryujinx_startup_script" &>/dev/null # Execute the startup script

        local ryujinx_appimage_final_path="${extra}/${emu}/Ryujinx.AppImage"
        cp "${temp_dir}/$emu/publish/Ryujinx" "$ryujinx_appimage_final_path" || show_error "Failed to copy Ryujinx executable."
        chmod a+x "$ryujinx_appimage_final_path" || show_error "Failed to make Ryujinx executable."

        # Make launcher script for Ryujinx
        local launcher_script="/userdata/system/switch/Ryujinx.AppImage"
        rm -f "$launcher_script"
        {
            echo '#!/bin/bash'
            echo 'export XDG_DATA_DIRS=/userdata/saves/flatpak/data/.local/share/flatpak/binaries/exports/share:/usr/local/share:/usr/share'
            echo 'export PATH=/userdata/system/.local/bin:/userdata/system/bin:/bin:/sbin:/usr/bin:/usr/sbin'
            echo 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket'
            echo 'export XDG_MENU_PREFIX=batocera-'
            echo 'export XDG_CONFIG_DIRS=/etc/xdg'
            echo 'export XDG_CURRENT_DESKTOP=XFCE'
            echo 'export DESKTOP_SESSION=XFCE'
            echo "/userdata/system/switch/extra/batocera-switch-ryujinx-fixes.sh"
            echo "/userdata/system/switch/extra/batocera-switch-sync-firmware.sh"
            echo "/userdata/system/switch/extra/batocera-switch-mousemove.sh &"
            echo "/userdata/system/switch/extra/batocera-switch-translator.sh &"
            echo "chmod a+x /userdata/system/switch/extra/lib/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders/* 2>/dev/null"
            echo "if [[ ! -e /usr/lib64/gdk-pixbuf-2.0 ]]; then cp -r /userdata/system/switch/extra/lib/gdk-pixbuf-2.0 /usr/lib64/ 2>/dev/null; fi"
            echo "chmod a+x /userdata/system/switch/extra/usr/bin/* 2>/dev/null"
            echo "cp -rL /userdata/system/switch/extra/usr/bin/* /usr/bin/ 2>/dev/null"
            echo "cp -rL /userdata/system/switch/extra/usr/bin/rev /userdata/system/switch/extra/batocera-switch-rev 2>/dev/null"
            echo "mkdir -p /usr/lib/x86_64-linux-gnu 2>/dev/null"
            echo "if [[ ! -e /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 ]]; then cp -r /userdata/system/switch/extra/lib/gdk-pixbuf-2.0 /usr/lib/x86_64-linux-gnu/ 2>/dev/null; fi"
            echo "cp /userdata/system/switch/extra/${emu}/xdg-mime /usr/bin/ 2>/dev/null"
            echo "if [ ! -L /userdata/system/configs/Ryujinx/bis/user/save ]; then mkdir -p /userdata/system/configs/Ryujinx/bis/user/save 2>/dev/null; rsync -au /userdata/saves/Ryujinx/ /userdata/system/configs/Ryujinx/bis/user/save/ 2>/dev/null; fi"
            echo "if [ ! -L /userdata/system/configs/yuzu/nand/user/save ]; then mkdir -p /userdata/system/configs/yuzu/nand/user/save 2>/dev/null; rsync -au /userdata/saves/yuzu/ /userdata/system/configs/yuzu/nand/user/save/ 2>/dev/null; fi"
            echo "mkdir -p /userdata/system/configs/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/yuzu/keys/ 2>/dev/null "
            echo "mkdir -p /userdata/system/.local/share/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/.local/share/yuzu/keys/ 2>/dev/null "
            echo "mkdir -p /userdata/system/configs/Ryujinx/system 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/Ryujinx/system/ 2>/dev/null "
            echo "rm -f /usr/bin/ryujinx 2>/dev/null; ln -s /userdata/system/switch/Ryujinx.AppImage /usr/bin/ryujinx 2>/dev/null"
            echo 'mkdir -p /userdata/system/switch/logs 2>/dev/null '
            echo 'log1=/userdata/system/switch/logs/Ryujinx-out.txt 2>/dev/null '
            echo 'log2=/userdata/system/switch/logs/Ryujinx-err.txt 2>/dev/null '
            echo 'rm -f "$log1" 2>/dev/null && rm -f "$log2" 2>/dev/null '
            echo 'ulimit -H -n 819200; ulimit -S -n 819200; ulimit -S -n 819200 Ryujinx.AppImage;'
            echo 'rom="$1" '
            echo 'rm -f /tmp/switchromname 2>/dev/null '
            echo 'echo "$rom" >> /tmp/switchromname 2>/dev/null '
            echo '/userdata/system/switch/extra/batocera-switch-nsz-converter.sh '
            echo 'rom="$(cat /tmp/switchromname)" '
            echo 'd=/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders '
            echo 'export LD_LIBRARY_PATH="/userdata/system/switch/extra/lib:/usr/lib:/lib:/usr/lib32:/lib32:$LD_LIBRARY_PATH" '
            echo 'export GDK_PIXBUF_MODULE_FILE="/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" '
            echo 'export GDK_PIXBUF_MODULEDIR="/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders" '
            echo 'export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$GDK_PIXBUF_MODULEDIR" '
            echo 'if [[ "$1" = "" ]]; then ' 
            echo 'DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 SCRIPT_DIR=/userdata/system/switch/extra/ryujinx DOTNET_EnableAlternateStackCheck=1 QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb LD_LIBRARY_PATH=/userdata/system/switch/extra/lib:/userdata/system/switch/extra/ryujinx:$LD_LIBRARY_PATH /userdata/system/switch/extra/ryujinx/Ryujinx.AppImage > >(tee "$log1") 2> >(tee "$log2" >&2) ' 
            echo 'else ' 
            echo 'DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 SCRIPT_DIR=/userdata/system/switch/extra/ryujinx DOTNET_EnableAlternateStackCheck=1 QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb LD_LIBRARY_PATH=/userdata/system/switch/extra/lib:/userdata/system/switch/extra/ryujinx:$LD_LIBRARY_PATH /userdata/system/switch/extra/ryujinx/Ryujinx.AppImage "$rom" > >(tee "$log1") 2> >(tee "$log2" >&2) ' 
            echo 'fi ' 
            echo ' ' 
        } >> "$launcher_script"
        dos2unix "$launcher_script" &>/dev/null
        chmod a+x "$launcher_script" &>/dev/null

        # Send version to cookie
        rm -f "${extra}/ryujinx/version.txt" 2>/dev/null
        echo "$ryujinx_version" >> "${extra}/ryujinx/version.txt"
    else
        log "ERROR" "RYUJINX tarball not found or invalid after download."
    fi
}

update_emulator_ryujinxavalonia() {
    log "INFO" "Attempting to update RYUJINX-AVALONIA..."
    local ryujinxava_appimage_path="${extra}/appimages/ryujinxava1403.tar.gz"
    local ryujinxava_dest_path="/userdata/system/switch/Ryujinx-Avalonia.AppImage"
    local ryujinxava_version="1403"
    local ryujinxava_checksum="442b76511ad0f727f290d8c1e380d2d2"
    local ryujinxava_fallback_url="https://foclabroc.freeboxos.fr:55973/share/aQz2Hnkinjx4x69L/ryujinxava1403.tar.gz"

    # Try to download from fallback first as original script seemed to prefer specific version
    download_file_fallback "$ryujinxava_appimage_path" "$ryujinxava_fallback_url"
    cp "$ryujinxava_appimage_path" "$ryujinxava_dest_path" || show_error "Failed to copy Ryujinx-Avalonia tarball."

    if [[ -f "$ryujinxava_dest_path" ]]; then
        local checksum_file=$(md5sum "$ryujinxava_dest_path" | awk '{print $1}')
        if [[ "$checksum_file" != "$ryujinxava_checksum" ]]; then
            log "WARN" "RYUJINX-AVALONIA tarball checksum mismatch. Attempting re-download from fallback."
            rm -f "$ryujinxava_appimage_path"
            download_file_fallback "$ryujinxava_appimage_path" "$ryujinxava_fallback_url"
            cp "$ryujinxava_appimage_path" "$ryujinxava_dest_path" || show_error "Failed to copy Ryujinx-Avalonia tarball after re-download."
            # Check checksum again after re-download
            checksum_file=$(md5sum "$ryujinxava_dest_path" | awk '{print $1}')
            if [[ "$checksum_file" != "$ryujinxava_checksum" ]]; then
                show_error "RYUJINX-AVALONIA download fail. Please put ryujinxava1403.tar.gz in /userdata/system/switch/appimages manually then relaunch script."
            fi
        fi
        log "INFO" "RYUJINX-AVALONIA   ${THEME_COLOR_OK_VAL}❯❯   /V${ryujinxava_version}/ ${GREEN}SUCCESS${X}"

        # Get dependencies for handling ryujinxavalonia (these are shared links)
        local link_tar_gh="system/switch/extra/batocera-switch-tar"
        local link_libselinux_gh="system/switch/extra/batocera-switch-libselinux.so.1"
        
        # Tar utility
        if [[ ! -e "${extra}/batocera-switch-tar" ]]; then 
            download_file_github "${extra}/batocera-switch-tar" "$link_tar_gh"
            chmod a+x "${extra}/batocera-switch-tar"
        fi
        
        # libselinux
        if [[ ! -e "/usr/lib/libselinux.so.1" ]]; then
            download_file_github "${extra}/batocera-switch-libselinux.so.1" "$link_libselinux_gh"
            if [[ -f "${extra}/batocera-switch-libselinux.so.1" ]] && [[ "$(wc -c "${extra}/batocera-switch-libselinux.so.1" | awk '{print $1}')" -lt "100" ]]; then 
                log "WARN" "Downloaded libselinux.so.1 appears to be too small, re-downloading."
                download_file_github "${extra}/batocera-switch-libselinux.so.1" "$link_libselinux_gh"   
            fi
            chmod a+x "${extra}/batocera-switch-libselinux.so.1"
            cp "${extra}/batocera-switch-libselinux.so.1" "/usr/lib/libselinux.so.1" 2>/dev/null
        fi
        if [[ -e "${extra}/batocera-switch-libselinux.so.1" ]]; then 
           cp "${extra}/batocera-switch-libselinux.so.1" "${extra}/libselinux.so.1" 2>/dev/null # Redundant copy to extra? Original script did this.
        fi

        local emu="ryujinxavalonia"
        mkdir -p "${extra}/$emu"
        rm -rf "${temp_dir}/$emu"
        mkdir -p "${temp_dir}/$emu"
        
        mv "$ryujinxava_dest_path" "${temp_dir}/$emu/ryujinxava-${ryujinxava_version}-linux_x64.tar.gz" || show_error "Failed to move Ryujinx-Avalonia tarball for extraction."
        
        download_file_github "${extra}/$emu/xdg-mime" "system/switch/extra/xdg-mime"
        chmod a+x "${extra}/$emu/xdg-mime"

        LD_LIBRARY_PATH="${extra}:/usr/lib64:/usr/lib:/lib:${LD_LIBRARY_PATH}" "${extra}/batocera-switch-tar" -xf "${temp_dir}/$emu/ryujinxava-${ryujinxava_version}-linux_x64.tar.gz" -C "${temp_dir}/$emu" || show_error "Failed to extract Ryujinx-Avalonia tarball."
        
        # Copy extracted files
        cp -rL "${temp_dir}/$emu/lib"* "${extra}/$emu/" 2>/dev/null
        mkdir -p "${extra}/$emu/mime"
        cp -rL "${temp_dir}/$emu/publish/mime/"* "${extra}/$emu/mime/" 2>/dev/null
        cp -rL "${temp_dir}/$emu/publish/"*.config "${extra}/$emu/" 2>/dev/null
        
        # Create startup script for Ryujinx-Avalonia (originally inside a temp file and sourced)
        local ryujinxava_startup_script="${extra}/${emu}/startup"
        rm -f "$ryujinxava_startup_script"
        {
            echo '#!/bin/bash'
            echo "cp ${extra}/$emu/lib* /lib/ 2>/dev/null"
        } >> "$ryujinxava_startup_script"
        dos2unix "$ryujinxava_startup_script" &>/dev/null
        chmod a+x "$ryujinxava_startup_script" &>/dev/null
        "$ryujinxava_startup_script" &>/dev/null # Execute the startup script

        local ryujinxava_appimage_final_path="/userdata/system/switch/Ryujinx-Avalonia.AppImage"
        cp "${temp_dir}/$emu/publish/Ryujinx.Ava" "$ryujinxava_appimage_final_path" || show_error "Failed to copy Ryujinx.Ava executable."
        chmod a+x "$ryujinxava_appimage_final_path" || show_error "Failed to make Ryujinx.Ava executable."

        # Make launcher script for Ryujinx-Avalonia
        local launcher_script="/userdata/system/switch/Ryujinx-Avalonia.AppImage"
        rm -f "$launcher_script"
        {
            echo '#!/bin/bash'
            echo 'export XDG_DATA_DIRS=/userdata/saves/flatpak/data/.local/share/flatpak/binaries/exports/share:/usr/local/share:/usr/share'
            echo 'export PATH=/userdata/system/.local/bin:/userdata/system/bin:/bin:/sbin:/usr/bin:/usr/sbin'
            echo 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket'
            echo 'export XDG_MENU_PREFIX=batocera-'
            echo 'export XDG_CONFIG_DIRS=/etc/xdg'
            echo 'export XDG_CURRENT_DESKTOP=XFCE'
            echo 'export DESKTOP_SESSION=XFCE'
            echo "/userdata/system/switch/extra/batocera-switch-ryujinx-fixes.sh"
            echo "/userdata/system/switch/extra/batocera-switch-sync-firmware.sh"
            echo "/userdata/system/switch/extra/batocera-switch-mousemove.sh &"
            echo "/userdata/system/switch/extra/batocera-switch-translator.sh &"
            echo "chmod a+x /userdata/system/switch/extra/lib/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/* 2>/dev/null"
            echo "chmod a+x /userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders/* 2>/dev/null"
            echo "if [[ ! -e /usr/lib64/gdk-pixbuf-2.0 ]]; then cp -r /userdata/system/switch/extra/lib/gdk-pixbuf-2.0 /usr/lib64/ 2>/dev/null; fi"
            echo "chmod a+x /userdata/system/switch/extra/usr/bin/* 2>/dev/null"
            echo "cp -rL /userdata/system/switch/extra/usr/bin/* /usr/bin/ 2>/dev/null"
            echo "cp -rL /userdata/system/switch/extra/usr/bin/rev /userdata/system/switch/extra/batocera-switch-rev 2>/dev/null"
            echo "mkdir -p /usr/lib/x86_64-linux-gnu 2>/dev/null"
            echo "if [[ ! -e /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 ]]; then cp -r /userdata/system/switch/extra/lib/gdk-pixbuf-2.0 /usr/lib/x86_64-linux-gnu/ 2>/dev/null; fi"
            echo "cp /userdata/system/switch/extra/${emu}/xdg-mime /usr/bin/ 2>/dev/null"
            echo "if [ ! -L /userdata/system/configs/Ryujinx/bis/user/save ]; then mkdir -p /userdata/system/configs/Ryujinx/bis/user/save 2>/dev/null; rsync -au /userdata/saves/Ryujinx/ /userdata/system/configs/Ryujinx/bis/user/save/ 2>/dev/null; fi"
            echo "if [ ! -L /userdata/system/configs/yuzu/nand/user/save ]; then mkdir -p /userdata/system/configs/yuzu/nand/user/save 2>/dev/null; rsync -au /userdata/saves/yuzu/ /userdata/system/configs/yuzu/nand/user/save/ 2>/dev/null; fi"
            echo "mkdir -p /userdata/system/configs/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/yuzu/keys/ 2>/dev/null "
            echo "mkdir -p /userdata/system/.local/share/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/.local/share/yuzu/keys/ 2>/dev/null "
            echo "mkdir -p /userdata/system/configs/Ryujinx/system 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/Ryujinx/system/ 2>/dev/null "
            echo "rm -f /usr/bin/ryujinx 2>/dev/null; ln -s /userdata/system/switch/Ryujinx-Avalonia.AppImage /usr/bin/ryujinx 2>/dev/null"
            echo 'mkdir -p /userdata/system/switch/logs 2>/dev/null '
            echo 'log1=/userdata/system/switch/logs/Ryujinx-Avalonia-out.txt 2>/dev/null '
            echo 'log2=/userdata/system/switch/logs/Ryujinx-Avalonia-err.txt 2>/dev/null '
            echo 'rm -f "$log1" 2>/dev/null && rm -f "$log2" 2>/dev/null '
            echo 'ulimit -H -n 819200; ulimit -S -n 819200; ulimit -S -n 819200 Ryujinx-Avalonia.AppImage;'
            echo 'rom="$1" '
            echo 'rm -f /tmp/switchromname 2>/dev/null '
            echo 'echo "$rom" >> /tmp/switchromname 2>/dev/null '
            echo '/userdata/system/switch/extra/batocera-switch-nsz-converter.sh '
            echo 'rom="$(cat /tmp/switchromname)" '
            echo 'd=/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders '
            echo 'export LD_LIBRARY_PATH="/userdata/system/switch/extra/lib:/usr/lib:/lib:/usr/lib32:/lib32:$LD_LIBRARY_PATH" '
            echo 'export GDK_PIXBUF_MODULE_FILE="/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" '
            echo 'export GDK_PIXBUF_MODULEDIR="/userdata/system/switch/extra/lib/gdk-pixbuf-2.0/2.10.0/loaders" '
            echo 'export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$GDK_PIXBUF_MODULEDIR" '
            echo 'if [[ "$1" = "" ]]; then ' 
            echo 'DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 SCRIPT_DIR=/userdata/system/switch/extra/ryujinxavalonia DOTNET_EnableAlternateStackCheck=1 QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb LD_LIBRARY_PATH=/userdata/system/switch/extra/lib:/userdata/system/switch/extra/ryujinxavalonia:$LD_LIBRARY_PATH /userdata/system/switch/extra/ryujinxavalonia/Ryujinx-Avalonia.AppImage > >(tee "$log1") 2> >(tee "$log2" >&2) ' 
            echo 'else ' 
            echo 'DRI_PRIME=1 AMD_VULKAN_ICD=RADVDISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1 XDG_MENU_PREFIX=batocera- XDG_CONFIG_DIRS=/etc/xdg XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=XFCE QT_FONT_DPI=96 QT_SCALE_FACTOR=1 GDK_SCALE=1 SCRIPT_DIR=/userdata/system/switch/extra/ryujinxavalonia DOTNET_EnableAlternateStackCheck=1 QT_PLUGIN_PATH=/usr/lib/qt/plugins:/userdata/system/switch/extra/lib/qt5plugins:/usr/plugins:${QT_PLUGIN_PATH} QT_QPA_PLATFORM_PLUGIN_PATH=${QT_PLUGIN_PATH} XDG_CONFIG_HOME=/userdata/system/configs XDG_CACHE_HOME=/userdata/system/.cache QT_QPA_PLATFORM=xcb LD_LIBRARY_PATH=/userdata/system/switch/extra/lib:/userdata/system/switch/extra/ryujinxavalonia:$LD_LIBRARY_PATH /userdata/system/switch/extra/ryujinxavalonia/Ryujinx-Avalonia.AppImage "$rom" > >(tee "$log1") 2> >(tee "$log2" >&2) ' 
            echo 'fi ' 
            echo ' ' 
        } >> "$launcher_script"
        dos2unix "$launcher_script" &>/dev/null
        chmod a+x "$launcher_script" &>/dev/null

        # Send version to cookie
        rm -f "${extra}/ryujinxavalonia/version.txt" 2>/dev/null
        echo "$ryujinxava_version" >> "${extra}/ryujinxavalonia/version.txt"
    else
        log "ERROR" "RYUJINX-AVALONIA tarball not found or invalid after download."
    fi
}

update_emulator_citron() {
    log "INFO" "Attempting to update CITRON..."
    local citron_appimage_filename="citron_stable-01c042048-linux-x86_64_v3.AppImage"
    local citron_appimage_path="${extra}/appimages/${citron_appimage_filename}"
    local citron_dest_path="/userdata/system/switch/citron.AppImage"
    local citron_version="0.12.25"
    local citron_download_url="https://git.citron-emu.org/Citron/Emulator/releases/download/${citron_version}/${citron_appimage_filename}"
    local citron_fallback_url="https://foclabroc.freeboxos.fr:55973/share/yIPp6usHOnAITnOT/citron0.10.0.AppImage" # Original fallback for older Citron

    # Always try direct download first as per user's request for specific version
    if ! wget -q --show-progress --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$citron_appimage_path" "$citron_download_url"; then
        log "WARN" "Failed to download specified Citron ${citron_version}. Attempting fallback to ${citron_fallback_url}."
        # If download of specific version fails, try the original fallback (Citron 0.10.0)
        download_file_fallback "$citron_appimage_path" "$citron_fallback_url"
        # Update version to fallback version if fallback was used
        if [[ -f "$citron_appimage_path" ]] && [[ "$(md5sum "$citron_appimage_path" | awk '{print $1}')" != "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6" ]]; then # Placeholder checksum for 0.10.0 if needed
            log "WARN" "Citron fallback download might be corrupted or incorrect version."
        fi
        citron_version="0.10.0" # Set version to fallback version if fallback was successful
    fi

    cp "$citron_appimage_path" "$citron_dest_path" || show_error "Failed to copy Citron AppImage."

    if [[ -f "$citron_dest_path" ]] && [[ $(stat -c%s "$citron_dest_path") -gt 2048 ]]; then
        log "INFO" "CITRON   ${THEME_COLOR_OK_VAL}❯❯   /V${citron_version}/ ${GREEN}SUCCESS${X}"
        chmod 777 "$citron_dest_path" &>/dev/null
        # Send version to cookie (not explicitly in original, but good for consistency)
        rm -f "${extra}/citron/version.txt" 2>/dev/null
        echo "$citron_version" >> "${extra}/citron/version.txt"
    else
        show_error "CITRON AppImage not found or invalid after download. Please put citron_${citron_version}.AppImage in /userdata/system/switch/appimages manually then relaunch script."
    fi
}

update_emulator_eden() {
    log "INFO" "Attempting to update EDEN..."
    local eden_appimage_path="/userdata/system/switch/eden.AppImage"
    local eden_version="v0.0.4" # Hardcoded in original script
    local eden_download_url="https://github.com/eden-emulator/Releases/releases/download/${eden_version}/Eden-Linux-${eden_version}-amd64-gcc-standard.AppImage"
    # Original script only used github, no freebox fallback for Eden

    if ! wget -q --show-progress --tries=3 --timeout=10 --no-check-certificate --no-cache --no-cookies -O "$eden_appimage_path" "$eden_download_url"; then
        log "WARN" "Failed to download Eden from GitHub. Continuing without Eden update."
        return # Do not show error, just skip this emulator if download fails for Eden
    fi

    if [[ -f "$eden_appimage_path" ]] && [[ $(stat -c%s "$eden_appimage_path") -gt 2048 ]]; then
        log "INFO" "EDEN   ${THEME_COLOR_OK_VAL}❯❯   /V${eden_version}/ ${GREEN}SUCCESS${X}"
        chmod 777 "$eden_appimage_path" &>/dev/null
        rm -f "${extra}/eden/version.txt" 2>/dev/null
        echo "$eden_version" >> "${extra}/eden/version.txt"
    else
        log "ERROR" "EDEN Appimage not found or invalid after download."
    fi
}

update_emulator_sudachi() {
    log "INFO" "Attempting to update SUDACHI..."
    local sudachi_appimage_path="${extra}/appimages/sudachi1.0.15.AppImage"
    local sudachi_dest_path="/userdata/system/switch/sudachi.AppImage"
    local sudachi_version="1.0.15"
    local sudachi_fallback_url="https://foclabroc.freeboxos.fr:55973/share/HYaogouYa05jIPgq/sudachi1.0.15.AppImage"

    # Try to download from fallback as original script seemed to prefer specific version
    download_file_fallback "$sudachi_appimage_path" "$sudachi_fallback_url"
    cp "$sudachi_appimage_path" "$sudachi_dest_path" || show_error "Failed to copy Sudachi AppImage."
    
    if [[ -f "$sudachi_dest_path" ]] && [[ $(stat -c%s "$sudachi_dest_path") -gt 2048 ]]; then
        log "INFO" "SUDACHI   ${THEME_COLOR_OK_VAL}❯❯   /V${sudachi_version}/ ${GREEN}SUCCESS${X}"
        chmod 777 "$sudachi_dest_path" &>/dev/null
        rm -rf "/userdata/system/switch/sudachi" 2>/dev/null # Original script removes this directory
        # Send version to cookie (not explicitly in original, but good for consistency)
        rm -f "${extra}/sudachi/version.txt" 2>/dev/null
        echo "$sudachi_version" >> "${extra}/sudachi/version.txt"
    else
        show_error "SUDACHI AppImage not found or invalid after download. Please put sudachi1.0.15.AppImage in /userdata/system/switch/appimages manually then relaunch script."
    fi
}

update_all_emulators() {
    local EMULATORS_ARRAY
    IFS='-' read -r -a EMULATORS_ARRAY <<< "$EMULATORS"
    
    local num_emulators_to_update="${#EMULATORS_ARRAY[@]}"
    local current_emu_num=1

    for emu_code in "${EMULATORS_ARRAY[@]}"; do
        log "INFO" "Processing emulator: $emu_code ($current_emu_num of $num_emulators_to_update)"
        case "$emu_code" in
            YUZUEA) update_emulator_yuzuea ;;;
            RYUJINX) update_emulator_ryujinx ;;;
            RYUJINXAVALONIA) update_emulator_ryujinxavalonia ;;;
            CITRON) update_emulator_citron ;;;
            EDEN) update_emulator_eden ;;;
            SUDACHI) update_emulator_sudachi ;;;
            *) log "WARN" "Unknown emulator code '$emu_code' specified in EMULATORS setting. Skipping." ;;
        esac
        ((current_emu_num++))
    done
    
    log "INFO" "${TEXT_COLOR_VAL}     ${TEXT_COLOR_VAL}   ${TEXT_COLOR_VAL} SWITCH EMULATORS INSTALLED ${GREEN}OK ${THEME_COLOR_VAL} │${X}"
    log "INFO" "${THEME_COLOR_VAL}──────────────────────────────────────┘${X}"
    log "INFO" "All selected emulators updated."
}


# --- post_install_tasks Function (refactored from original post-install) ---
post_install_tasks() {
    log "INFO" "Starting post-installation tasks."
    # get additional files (moved from original post-install start)
    log "INFO" "Downloading additional utility files..."
    download_file_github "${extra}/xdg.tar.gz" "system/switch/extra/xdg.tar.gz"
    cd "${extra}" && rm -rf "${extra}/xdg" && tar -xf xdg.tar.gz || log "ERROR" "Failed to extract xdg.tar.gz"
    download_file_github "${extra}/batocera-switch-xdg.sh" "system/switch/extra/batocera-switch-xdg.sh"
    dos2unix "${extra}/batocera-switch-xdg.sh" &>/dev/null && chmod a+x "${extra}/batocera-switch-xdg.sh"

    rm -f "/userdata/system/switch/configgen/mapping.csv" 2>/dev/null # Obsolete file

    download_file_github "${extra}/batocera-switch-mousemove.sh" "system/switch/extra/batocera-switch-mousemove.sh"
    dos2unix "${extra}/batocera-switch-mousemove.sh" &>/dev/null && chmod a+x "${extra}/batocera-switch-mousemove.sh"
    download_file_github "${extra}/batocera-switch-libxdo.so.3" "system/switch/extra/batocera-switch-libxdo.so.3"
    download_file_github "${extra}/batocera-switch-xdotool" "system/switch/extra/batocera-switch-xdotool"
    chmod a+x "${extra}/batocera-switch-lib"* &>/dev/null 
    chmod a+x "${extra}/batocera-switch-xdo"* &>/dev/null 

    download_file_github "${extra}/batocera-switch-sync-firmware.sh" "system/switch/extra/batocera-switch-sync-firmware.sh"
    dos2unix "${extra}/batocera-switch-sync-firmware.sh" &>/dev/null && chmod a+x "${extra}/batocera-switch-sync-firmware.sh"

    download_file_github "${extra}/batocera-switch-stat" "system/switch/extra/batocera-switch-stat"
    chmod a+x "${extra}/batocera-switch-stat" &>/dev/null 

    # NSZ Converter
    download_file_github "${extra}/nsz.zip" "system/switch/extra/nsz.zip"
    download_file_github "${extra}/batocera-switch-rev" "system/switch/extra/batocera-switch-rev"
    chmod a+x "${extra}/batocera-switch-rev" &>/dev/null
    download_file_github "${extra}/batocera-switch-nsz-converter.sh" "system/switch/extra/batocera-switch-nsz-converter.sh"
    dos2unix "${extra}/batocera-switch-nsz-converter.sh" &>/dev/null && chmod a+x "${extra}/batocera-switch-nsz-converter.sh"
    cd "${extra}" && rm -rf nsz && unzip -o -qq nsz.zip || log "ERROR" "Failed to extract nsz.zip"

    # gdk/svg libs for ryujinx
    log "INFO" "Downloading GDK/SVG libraries for Ryujinx..."
    download_file_github "${extra}/lib.tar.gz" "system/switch/extra/lib.tar.gz"
    cd "${extra}" && rm -rf lib && tar -xf lib.tar.gz || log "ERROR" "Failed to extract lib.tar.gz"
    
    download_file_github "${extra}/ryujinx-controller-patcher.sh" "system/switch/extra/ryujinx-controller-patcher.sh"
    dos2unix "${extra}/ryujinx-controller-patcher.sh" &>/dev/null && chmod a+x "${extra}/ryujinx-controller-patcher.sh"

    download_file_github "${extra}/yuzu-controller-patcher.sh" "system/switch/extra/yuzu-controller-patcher.sh"
    dos2unix "${extra}/yuzu-controller-patcher.sh" &>/dev/null && chmod a+x "${extra}/yuzu-controller-patcher.sh"

    download_file_github "${extra}/batocera-switch-patcher.sh" "system/switch/extra/batocera-switch-patcher.sh"
    dos2unix "${extra}/batocera-switch-patcher.sh" &>/dev/null && chmod a+x "${extra}/batocera-switch-patcher.sh"

    # --- PREPARE BATOCERA-SWITCH-STARTUP FILE ---
    log "INFO" "Preparing batocera-switch-startup file..."
    local startup_file="/userdata/system/switch/extra/batocera-switch-startup"
    rm -f "$startup_file"
    {
        echo '#!/bin/bash'
        echo '#'
        echo '#\ check language'
        echo '/userdata/system/switch/extra/batocera-switch-translator.sh 2>/dev/null &'
        echo '#\ prepare system'
        echo 'cp /userdata/system/switch/extra/batocera-switch-rev /usr/bin/rev 2>/dev/null'
        echo 'mkdir -p /userdata/system/switch/logs 2>/dev/null'
        echo 'sysctl -w vm.max_map_count=2147483642 1>/dev/null'
        echo "extra_path='/userdata/system/switch/extra'" # Use extra_path to avoid conflict with $extra from main script
        echo 'cp "$extra_path"/*.desktop /usr/share/applications/ 2>/dev/null'
        echo '#'
        echo 'if [[ -e "/lib/libthai.so.0.3.1" ]] || [[ -e "/usr/lib/libthai.so.0.3.1" ]]; then :; else cp "$extra_path"/libthai.so.0.3.1 /usr/lib/libthai.so.0.3.1 2>/dev/null; fi'
        echo 'if [[ -e "/lib/libthai.so.0.3" ]] || [[ -e "/usr/lib/libthai.so.0.3" ]]; then :; else cp "$extra_path"/batocera-switch-libthai.so.0.3 /usr/lib/libthai.so.0.3 2>/dev/null; fi'
        echo 'if [[ -e "/lib/libselinux.so.1" ]] || [[ -e "/usr/lib/libselinux.so.1" ]]; then :; else cp "$extra_path"/batocera-switch-libselinux.so.1 /usr/lib/libselinux.so.1 2>/dev/null; fi'
        echo 'if [[ -e "/lib/libtinfo.so.6" ]] || [[ -e "/usr/lib/libtinfo.so.6" ]]; then :; else cp "$extra_path"/batocera-switch-libtinfo.so.6 /usr/lib/libtinfo.so.6 2>/dev/null; fi'
        echo '#'
        # Link ryujinx config folders
        echo '#\ link ryujinx config folders'
        echo 'mkdir -p /userdata/system/configs/Ryujinx 2>/dev/null'
        echo 'if [[ ! -L /userdata/system/.config/Ryujinx ]]; then'
        echo '    mv /userdata/system/configs/Ryujinx /userdata/system/configs/Ryujinx_tmp 2>/dev/null'
        echo '    cp -rL /userdata/system/.config/Ryujinx/* /userdata/system/configs/Ryujinx_tmp 2>/dev/null'
        echo '    rm -rf /userdata/system/.config/Ryujinx'
        echo '    mv /userdata/system/configs/Ryujinx_tmp /userdata/system/configs/Ryujinx 2>/dev/null'
        echo '    ln -s /userdata/system/configs/Ryujinx /userdata/system/.config/Ryujinx 2>/dev/null'
        echo 'fi'
        echo 'rm /userdata/system/configs/Ryujinx/Ryujinx 2>/dev/null # Remove old executable link'
        echo '#'
        # Link ryujinx saves folders
        echo '#\ link ryujinx saves folders'
        echo 'mkdir -p /userdata/saves/Ryujinx 2>/dev/null'
        echo 'if [[ ! -L /userdata/system/configs/Ryujinx/bis/user/save ]]; then'
        echo '    mv /userdata/saves/Ryujinx /userdata/saves/Ryujinx_tmp 2>/dev/null'
        echo '    cp -rL /userdata/system/configs/Ryujinx/bis/user/save/* /userdata/saves/Ryujinx_tmp/ 2>/dev/null'
        echo '    rm -rf /userdata/system/configs/Ryujinx/bis/user/save 2>/dev/null'
        echo '    mv /userdata/saves/Ryujinx_tmp /userdata/saves/Ryujinx 2>/dev/null'
        echo '    mkdir -p /userdata/system/configs/Ryujinx/bis/user 2>/dev/null'
        echo '    ln -s /userdata/saves/Ryujinx /userdata/system/configs/Ryujinx/bis/user/save 2>/dev/null'
        echo 'fi'
        echo 'rm /userdata/saves/Ryujinx/Ryujinx 2>/dev/null # Remove old executable link'
        echo '#'
        # Link yuzu config folders
        echo '#\ link yuzu config folders'
        echo 'mkdir -p /userdata/system/configs/yuzu 2>/dev/null'
        echo 'if [[ ! -L /userdata/system/.config/yuzu ]]; then'
        echo '    mv /userdata/system/configs/yuzu /userdata/system/configs/yuzu_tmp 2>/dev/null'
        echo '    cp -rL /userdata/system/.config/yuzu/* /userdata/system/configs/yuzu_tmp 2>/dev/null'
        echo '    cp -rL /userdata/system/.local/share/yuzu/* /userdata/system/configs/yuzu_tmp 2>/dev/null'
        echo '    rm -rf /userdata/system/.config/yuzu'
        echo '    rm -rf /userdata/system/.local/share/yuzu'
        echo '    mv /userdata/system/configs/yuzu_tmp /userdata/system/configs/yuzu 2>/dev/null'
        echo '    ln -s /userdata/system/configs/yuzu /userdata/system/.config/yuzu 2>/dev/null'
        echo '    ln -s /userdata/system/configs/yuzu /userdata/system/.local/share/yuzu 2>/dev/null'
        echo 'fi'
        echo 'rm /userdata/system/configs/yuzu/yuzu 2>/dev/null # Remove old executable link'
        echo '#'
        # Link yuzu saves folders
        echo '#\ link yuzu saves folders'
        echo 'mkdir -p /userdata/saves/yuzu 2>/dev/null'
        echo 'if [[ ! -L /userdata/system/configs/yuzu/nand/user/save ]]; then'
        echo '    mv /userdata/saves/yuzu /userdata/saves/yuzu_tmp 2>/dev/null'
        echo '    cp -rL /userdata/system/configs/yuzu/nand/user/save/* /userdata/saves/yuzu_tmp/ 2>/dev/null'
        echo '    rm -rf /userdata/system/configs/yuzu/nand/user/save 2>/dev/null'
        echo '    mv /userdata/saves/yuzu_tmp /userdata/saves/yuzu 2>/dev/null'
        echo '    mkdir -p /userdata/system/configs/yuzu/nand/user 2>/dev/null'
        echo '    ln -s /userdata/saves/yuzu /userdata/system/configs/yuzu/nand/user/save 2>/dev/null'
        echo 'fi'
        echo 'rm /userdata/saves/yuzu/yuzu 2>/dev/null # Remove old executable link'
        echo '#'
        # Link yuzu and ryujinx keys folders to bios/switch
        echo '#\ link yuzu and ryujinx keys folders to bios/switch '
        echo 'mkdir -p /userdata/system/configs/yuzu/keys 2>/dev/null'
        echo 'mkdir -p /userdata/system/configs/Ryujinx/system 2>/dev/null'
        echo 'if [[ ! -L /userdata/system/configs/yuzu/keys ]]; then'
        echo '    cp -rL /userdata/system/configs/yuzu/keys/* /userdata/bios/switch/ 2>/dev/null # Copy existing keys if any'
        echo '    rm -rf /userdata/system/configs/yuzu/keys 2>/dev/null'
        echo '    ln -s /userdata/bios/switch /userdata/system/configs/yuzu/keys 2>/dev/null'
        echo 'fi'
        echo 'if [[ ! -L /userdata/system/configs/Ryujinx/system ]]; then'
        echo '    cp -rL /userdata/system/configs/Ryujinx/system/* /userdata/bios/switch/ 2>/dev/null # Copy existing keys if any'
        echo '    rm -rf /userdata/system/configs/Ryujinx/system 2>/dev/null'
        echo '    ln -s /userdata/bios/switch /userdata/system/configs/Ryujinx/system 2>/dev/null'
        echo 'fi'
        echo 'mkdir -p /userdata/system/.local/share/yuzu/keys 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/.local/share/yuzu/keys/ 2>/dev/null '
        echo 'mkdir -p /userdata/system/configs/Ryujinx/system 2>/dev/null; cp -rL /userdata/bios/switch/*.keys /userdata/system/configs/Ryujinx/system/ 2>/dev/null '
        echo '#'
        # Fix batocera.linux folder issue for f1/apps menu
        echo "sed -i 's/inline_limit=\"20\"/inline_limit=\"256\"/' /etc/xdg/menus/batocera-applications.menu 2>/dev/null"
        echo "sed -i 's/inline_limit=\"60\"/inline_limit=\"256\"/' /etc/xdg/menus/batocera-applications.menu 2>/dev/null"
        echo '#'
        # Add xdg integration with pcmanfm for f1 emu configs
        echo '  fs=$( blkid | grep "$(df -h /userdata | awk '\''END {print $1}'\'' )" | sed '\''s,^.*TYPE=,,g'\'') | sed '\''s,",,,g'\'') | tr '\''a-z\'' '\''A-Z'\'') ' 
        echo '    if [[ "$fs" == *"EXT"* ]] || [[ "$fs" == *"BTR"* ]]; then ' 
        echo '      /userdata/system/switch/extra/batocera-switch-xdg.sh ' 
        echo '    fi' 
        echo '#'
    } >> "$startup_file"
    dos2unix "$startup_file" &>/dev/null
    chmod a+x "$startup_file" &>/dev/null
    
    # Run the startup script now
    "$startup_file" &>/dev/null &
    log "INFO" "Batocera Switch startup script executed."

    # --- ADD TO BATOCERA AUTOSTART > /USERDATA/SYSTEM/CUSTOM.SH ---
    log "INFO" "Updating custom.sh for autostart..."
    local custom_sh="/userdata/system/custom.sh"
    local startup_script_entry="/userdata/system/switch/extra/batocera-switch-startup"

    dos2unix "$custom_sh" &>/dev/null # Ensure custom.sh is Unix format

    if [[ -f "$custom_sh" ]]; then
        if ! grep -q "$startup_script_entry" "$custom_sh"; then
            echo -e "\n$startup_script_entry\n" >> "$custom_sh"
            log "INFO" "Added startup script to custom.sh"
        else
            log "INFO" "Startup script already present in custom.sh"
        fi
    else
        echo -e "#!/bin/bash\n\n""$startup_script_entry""\n" > "$custom_sh"
        log "INFO" "Created custom.sh with startup script entry."
    fi
    chmod a+x "$custom_sh" &>/dev/null

    # --- CLEAR OLD V34- CUSTOM.SH LINE ---
    log "INFO" "Checking for old custom.sh entries..."
    if uname -a | grep -q "x86_64"; then
        if [[ "$(uname -a | awk '{print $3}')" > "5.18.00" ]]; then # Checks for kernel version
            local remove_line="cat /userdata/system/configs/emulationstation/add_feat_os.cfg /userdata/system/configs/emulationstation/add_feat_switch.cfg"
            if grep -q "$remove_line" "$custom_sh"; then
                log "INFO" "Removing old V34- custom.sh entry."
                sed -i "\%\%${remove_line}\%d" "$custom_sh" # Remove line using sed
            fi
            # Also remove old emulationstation config file if system upgraded
            rm -f "/userdata/system/configs/emulationstation/add_feat_switch.cfg" 2>/dev/null
        fi
    fi
    mkdir -p /userdata/system/switch/extra/backup # Ensure backup directory exists

    # --- REMOVE OLD UPDATERS ---
    log "INFO" "Removing old updater scripts..."
    rm /userdata/roms/ports/update{yuzu,yuzuea,yuzuEA,ryujinx,ryujinxavalonia}.sh 2>/dev/null

    # --- AUTOMATICALLY PULL THE LATEST EMULATORS FEATURES UPDATES / ALSO UPDATE THESE FILES: ---
    log "INFO" "Updating latest emulator features and other core files..."
    # Directories for core configgen components (ensure they exist)
    mkdir -p /userdata/system/switch/configgen/generators/{yuzu,ryujinx} \
             /userdata/system/configs/{emulationstation,evmapy} \
             /userdata/system/switch/extra

    download_file_github "/userdata/system/configs/evmapy/switch.keys" "system/configs/evmapy/switch.keys"
    dos2unix "/userdata/system/configs/evmapy/switch.keys" &>/dev/null

    download_file_github "/userdata/system/configs/emulationstation/es_features_switch.cfg" "system/configs/emulationstation/es_features_switch.cfg"
    dos2unix "/userdata/system/configs/emulationstation/es_features_switch.cfg" &>/dev/null

    download_file_github "/userdata/system/configs/emulationstation/es_systems_switch.cfg" "system/switch/configgen/emulationstation/es_systems_switch.cfg" # Updated from original path to match configgen
    dos2unix "/userdata/system/configs/emulationstation/es_systems_switch.cfg" &>/dev/null

    download_file_github "/userdata/system/switch/configgen/switchlauncher.py" "system/switch/configgen/switchlauncher.py"
    
    download_file_github "/userdata/system/switch/configgen/GeneratorImporter.py" "system/switch/configgen/GeneratorImporter.py"

    download_file_github "/userdata/system/switch/configgen/generators/ryujinx/ryujinxMainlineGenerator.py" "system/switch/configgen/generators/ryujinx/ryujinxMainlineGenerator.py"

    download_file_github "/userdata/system/switch/configgen/generators/yuzu/yuzuMainlineGenerator.py" "system/switch/configgen/generators/yuzu/yuzuMainlineGenerator.py"

    download_file_github "/userdata/system/switch/extra/batocera-config-eden" "system/switch/extra/batocera-config-eden"

    # Update SSH Updater, main Updater, and Ports Updater scripts
    download_file_github "/userdata/system/switch/extra/batocera-switch-sshupdater.sh" "system/switch/extra/batocera-switch-sshupdater.sh"
    dos2unix "/userdata/system/switch/extra/batocera-switch-sshupdater.sh" &>/dev/null && chmod a+x "/userdata/system/switch/extra/batocera-switch-sshupdater.sh"

    download_file_github "/userdata/system/switch/extra/batocera-switch-updater.sh" "system/switch/extra/batocera-switch-updater.sh"
    dos2unix "/userdata/system/switch/extra/batocera-switch-updater.sh" &>/dev/null && chmod a+x "/userdata/system/switch/extra/batocera-switch-updater.sh"

    download_file_github "/userdata/roms/ports/Switch Updater.sh" "roms/ports/Switch%20Updater.sh" # URL Encoded for space
    dos2unix "/userdata/roms/ports/Switch Updater.sh" &>/dev/null && chmod a+x "/userdata/roms/ports/Switch Updater.sh"

    download_file_github "/userdata/roms/ports/Switch Updater.sh.keys" "roms/ports/Switch%20Updater.sh.keys" # URL Encoded for space
    dos2unix "/userdata/roms/ports/Switch Updater.sh.keys" &>/dev/null

    download_file_github "/userdata/system/switch/extra/batocera-switch-patcher.sh" "system/switch/extra/batocera-switch-patcher.sh"
    dos2unix "/userdata/system/switch/extra/batocera-switch-patcher.sh" &>/dev/null && chmod a+x "/userdata/system/switch/extra/batocera-switch-patcher.sh"

    # --- GET RYUJINX 942 libSDL2.so ---
    log "INFO" "Updating libSDL2.so for Ryujinx..."
    local ryujinx_sdl_path="/userdata/system/switch/extra/sdl/libSDL2.so"
    download_file_github "$ryujinx_sdl_path" "system/switch/extra/batocera-switch-libSDL2.so"
    chmod a+x "$ryujinx_sdl_path" &>/dev/null

    # --- REMOVE NEW VER YUZU QUIT PROMPT ---
    log "INFO" "Adjusting Yuzu quit prompt setting..."
    if [[ -e "/userdata/system/configs/yuzu/qt-config.ini" ]]; then 
       sed -i 's,confirmStop=0,confirmStop=2,g' /userdata/system/configs/yuzu/qt-config.ini 2>/dev/null
       sed -i 's,confirmStop\default=true,confirmStop\default=false,g' /userdata/system/configs/yuzu/qt-config.ini 2>/dev/null
    fi

    # --- GET TRANSLATIONS ---
    log "INFO" "Updating translations and translator script..."
    local translations_path="/userdata/system/switch/extra/translations"
    mkdir -p "${translations_path}/en_US" "${translations_path}/fr_FR"
    download_file_github "${translations_path}/en_US/es_features_switch.cfg" "system/switch/extra/translations/en_US/es_features_switch.cfg"
    dos2unix "${translations_path}/en_US/es_features_switch.cfg" &>/dev/null
    download_file_github "${translations_path}/fr_FR/es_features_switch.cfg" "system/switch/extra/translations/fr_FR/es_features_switch.cfg"
    dos2unix "${translations_path}/fr_FR/es_features_switch.cfg" &>/dev/null

    download_file_github "/userdata/system/switch/extra/batocera-switch-translator.sh" "system/switch/extra/batocera-switch-translator.sh"
    dos2unix "/userdata/system/switch/extra/batocera-switch-translator.sh" &>/dev/null && chmod 777 "/userdata/system/switch/extra/batocera-switch-translator.sh"

    # --- GET RYUJINX-FIXES.SH ---
    download_file_github "/userdata/system/switch/extra/batocera-switch-ryujinx-fixes.sh" "system/switch/extra/batocera-switch-ryujinx-fixes.sh"
    dos2unix "/userdata/system/switch/extra/batocera-switch-ryujinx-fixes.sh" &>/dev/null && chmod 777 "/userdata/system/switch/extra/batocera-switch-ryujinx-fixes.sh"

    chmod 777 /userdata/system/switch/extra/*.sh 2>/dev/null

    # --- CLEAR TEMP & COOKIE ---
    log "INFO" "Cleaning temporary files and old cookies..."
    rm -rf /userdata/system/switch/extra/downloads /userdata/system/switch/extra/display.settings /userdata/system/switch/extra/updater.settings \
           /usr/share/applications/yuzu.desktop /usr/share/applications/Ryujinx-LDN.desktop \
           /userdata/system/switch/extra/yuzu /userdata/system/switch/extra/ryujinxldn \
           /userdata/system/switch/appimages/ryujinxldn313.tar.gz /userdata/system/switch/appimages/yuzu1734.AppImage \
           /userdata/system/switch/yuzu.AppImage /userdata/system/switch/Ryujinx-LDN.AppImage \
           /userdata/system/switch/extra/yuzu.desktop /userdata/system/switch/extra/Ryujinx-LDN.desktop 2>/dev/null

    log "INFO" "Post-installation tasks completed."
}

# --- Post-Installation Messages ---
post_install_messages() {
    clear
    log "INFO" "   ${BLUE}INSTALLER BY ${GREEN}MDY-DEVELOPER${X}"
    log "INFO" "   ${GREEN}${APPNAME} UPDATED${X}" 
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
}

# --- Script Execution ---
main_execution() {
    main
    # After main, if all goes well, it would show post_install_messages.
    # The original script had a conditional post-install. I'll maintain that logic.
    if [[ -f /userdata/system/switch/extra/installation ]]; then # This file is touched if updater finished successfully
        rm -f /userdata/system/switch/extra/installation 2>/dev/null # Clean up
        post_install_messages
    else
        clear
        show_error "Updater failed unexpectedly. Please check the log file: ${LOG_FILE}"
        log "INFO" "Try running the script again."
        log "INFO" "If it still fails, check internet connection or manual installation methods."
        sleep 5
        exit 1
    fi
}

main_execution