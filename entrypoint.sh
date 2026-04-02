#!/bin/bash

# --- Log Color Definitions ---
export RESET='\033[0m'
export RedBold='\033[1;31m'
export GreenBold='\033[1;32m'
export YellowBold='\033[1;33m'
export CyanBold='\033[1;36m'

LogAction() { printf "${CyanBold}==== %s ====${RESET}\n" "$1"; }
LogSuccess() { printf "${GreenBold}%s${RESET}\n" "$1"; }
LogWarn() { printf "${YellowBold}%s${RESET}\n" "$1"; }
LogError() { printf "${RedBold}%s${RESET}\n" "$1"; }

# --- Compose Port Sync (Coolify Context) ---
# Captures environment ports defined in Docker Compose
INTERNAL_UDP_MAIN=${PORT_UDP_MAIN:-16261}
INTERNAL_UDP_DIRECT=${PORT_UDP_DIRECT:-16262}
INTERNAL_TCP_RCON=${PORT_TCP_RCON:-27015}

# --- Project Branding Display ---
if [ -f "/home/steam/server/branding" ]; then
    cat /home/steam/server/branding
    # Added a newline \n at the beginning as requested
    printf "\n${CyanBold}Developed by Terule | IG: @aguiar_fael | GitHub: https://github.com/Terule${RESET}\n\n"
fi

# --- 1. User ID Mapping (PUID/PGID) ---
if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    LogAction "Syncing container permissions with host (PUID:$PUID PGID:$PGID)"
    groupmod -o -g "$PGID" steam
    usermod -o -u "$PUID" steam
fi

# Ensure folders exist and belong to steam user before any operation
mkdir -p /home/steam/.steam/sdk64 /home/steam/.steam/root "$CONFIG_DIR/Server" "$GAME_DIR"
chown -R steam:steam /home/steam/ /project-zomboid /project-zomboid-config

# --- 2. Admin Security Check ---
if [ -z "${ADMIN_PASSWORD}" ] || [ "${ADMIN_PASSWORD}" == "admin" ] || [ "${ADMIN_PASSWORD}" == "CHANGEME" ]; then
    LogWarn "SECURITY WARNING: ADMIN_PASSWORD is weak or not defined in Coolify!"
fi

# --- 3. SteamCMD Update Logic & Save Protection ---
if [ "$SERVER_BRANCH" == "outdatedunstable" ]; then
    LogWarn "!!! OUTDATEDUNSTABLE (42.15) DETECTED !!!"
    LogWarn "Automatic updates disabled to prevent B42.16+ corruption."
    UPDATE_ON_START="false"
fi

if [ "$UPDATE_ON_START" = "true" ] || [ ! -f "/project-zomboid/ProjectZomboid64" ]; then
    LogAction "Updating game files (Branch: ${SERVER_BRANCH:-Stable})..."
    
    if [ -n "${SERVER_BRANCH}" ]; then
        envsubst < /home/steam/server/scripts/install_version.scmd > /tmp/run.scmd
    else
        cp /home/steam/server/scripts/install.scmd /tmp/run.scmd
    fi
    su - steam -c "${STEAMCMD_PATH:-/usr/bin/steamcmd} +runscript /tmp/run.scmd"
fi

# --- 4. Memory Management (JSON Patch) ---
JSON_FILE="/project-zomboid/ProjectZomboid64.json"
if [ -f "$JSON_FILE" ]; then
    LogAction "Applying memory patch to ${MEMORY_XMX_GB}GB"
    su - steam -c "jq \".vmArgs |= map(if startswith(\\\"-Xmx\\\") then \\\"-Xmx${MEMORY_XMX_GB}G\\\" else . end)\" $JSON_FILE > $JSON_FILE.tmp && mv $JSON_FILE.tmp $JSON_FILE"
fi

# --- 5. Configuration Patching (.ini and SandboxVars.lua) ---
INI_FILE="$CONFIG_DIR/Server/${SERVER_NAME}.ini"
SANDBOX_FILE="$CONFIG_DIR/Server/${SERVER_NAME}_SandboxVars.lua"

if [ -f "$INI_FILE" ]; then
    LogAction "Applying .ini config patches (Coolify Variables)"
    # Base Settings
    sed -i "s/^PVP=.*/PVP=${PVP:-false}/" "$INI_FILE"
    sed -i "s/^MaxPlayers=.*/MaxPlayers=${MAX_PLAYERS:-10}/" "$INI_FILE"
    sed -i "s/^RCONPassword=.*/RCONPassword=${RCON_PASSWORD}/" "$INI_FILE"
    sed -i "s/^RCONEnabled=.*/RCONEnabled=true/" "$INI_FILE"
    sed -i "s/^RCONPort=.*/RCONPort=${INTERNAL_TCP_RCON}/" "$INI_FILE"
    sed -i "s/^Password=.*/Password=${SERVER_PASSWORD}/" "$INI_FILE"
    sed -i "s/^Public=.*/Public=${PUBLIC:-false}/" "$INI_FILE"
    sed -i "s/^DefaultPort=.*/DefaultPort=${INTERNAL_UDP_MAIN}/" "$INI_FILE"
    sed -i "s/^UDPPort=.*/UDPPort=${INTERNAL_UDP_DIRECT}/" "$INI_FILE"
    
    # Visual and Identification Settings
    sed -i "s/^MouseOverToSeeDisplayName=.*/MouseOverToSeeDisplayName=${MOUSE_OVER_DISPLAY_NAME:-false}/" "$INI_FILE"
    sed -i "s/^DisplayUserName=.*/DisplayUserName=${DISPLAY_USER_NAME:-false}/" "$INI_FILE"
    sed -i "s/^ShowFirstAndLastName=.*/ShowFirstAndLastName=${SHOW_FIRST_LAST_NAME:-true}/" "$INI_FILE"
    sed -i "s/^SneakModeHideFromOtherPlayers=.*/SneakModeHideFromOtherPlayers=${SNEAK_HIDE_PLAYERS:-false}/" "$INI_FILE"
    sed -i "s/^MapRemotePlayerVisibility=.*/MapRemotePlayerVisibility=${MAP_REMOTE_VISIBILITY:-3}/" "$INI_FILE"
fi

if [ -f "$SANDBOX_FILE" ]; then
    LogAction "Applying SandboxVars.lua patches"
    sed -i "s/AllowMiniMap = .*/AllowMiniMap = ${ALLOW_MINIMAP:-true},/" "$SANDBOX_FILE"
fi

# --- 6. Graceful Shutdown (RCON Save & Quit) ---
term_handler() {
    LogWarn "Stop signal received! Executing graceful shutdown via RCON..."
    rcon-cli -a 127.0.0.1:${INTERNAL_TCP_RCON} -p "$RCON_PASSWORD" "save"
    rcon-cli -a 127.0.0.1:${INTERNAL_TCP_RCON} -p "$RCON_PASSWORD" "quit"
    sleep 10
    exit 0
}
trap 'term_handler' SIGTERM

# --- 7. Server Execution ---
LogSuccess "Starting Project Zomboid Dedicated Server!"

# Fix for libsteam_api.so not found: 
# We need to add the game directory and the linux64 subdirectory to LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$GAME_DIR/linux64:$GAME_DIR:$LD_LIBRARY_PATH"

su - steam -c "export LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\" && $GAME_DIR/ProjectZomboid64 -batchmode \
    -cachedir=$CONFIG_DIR \
    -adminusername \"$ADMIN_USERNAME\" \
    -adminpassword \"$ADMIN_PASSWORD\" \
    -port $INTERNAL_UDP_MAIN \
    -servername $SERVER_NAME \
    $EXTRA_FLAGS" &

killpid="$!"
wait "$killpid"