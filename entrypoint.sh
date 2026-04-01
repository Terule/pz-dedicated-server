#!/bin/bash

# --- Color Definitions for Logging ---
export RESET='\033[0m'
export RedBold='\033[1;31m'
export GreenBold='\033[1;32m'
export YellowBold='\033[1;33m'
export CyanBold='\033[1;36m'

LogAction() { printf "${CyanBold}==== %s ====${RESET}\n" "$1"; }
LogSuccess() { printf "${GreenBold}%s${RESET}\n" "$1"; }
LogWarn() { printf "${YellowBold}%s${RESET}\n" "$1"; }
LogError() { printf "${RedBold}%s${RESET}\n" "$1"; }

# --- Display Project Branding & Credits ---
if [ -f "/home/steam/server/branding" ]; then
    cat /home/steam/server/branding
    printf "${CyanBold}Developed by Terule | IG: @aguiar_fael | GitHub: https://github.com/Terule${RESET}\n\n"
fi

# --- 1. User ID Mapping (PUID/PGID) ---
if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    LogAction "Syncing container permissions with host (PUID:$PUID PGID:$PGID)"
    groupmod -o -g "$PGID" steam
    usermod -o -u "$PUID" steam
fi
chown -R steam:steam /project-zomboid /project-zomboid-config /home/steam/

# --- 2. Admin Security Check ---
if [ -z "${ADMIN_PASSWORD}" ] || [ "${ADMIN_PASSWORD}" == "admin" ] || [ "${ADMIN_PASSWORD}" == "CHANGEME" ]; then
    LogWarn "SECURITY WARNING: ADMIN_PASSWORD is weak or not set! Check your .env file."
fi

# --- 3. SteamCMD Update Logic & Save Protection ---
# Logic to prevent accidental updates from 42.15 to 42.16+
if [ "$SERVER_BRANCH" == "outdatedunstable" ]; then
    LogWarn "!!! OUTDATEDUNSTABLE (42.15) DETECTED !!!"
    LogWarn "Automatic updates are DISABLED to protect your save from B42.16+ incompatibility."
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
    LogAction "Patching memory settings to ${MEMORY_XMX_GB}GB"
    su - steam -c "jq \".vmArgs |= map(if startswith(\\\"-Xmx\\\") then \\\"-Xmx${MEMORY_XMX_GB}G\\\" else . end)\" $JSON_FILE > $JSON_FILE.tmp && mv $JSON_FILE.tmp $JSON_FILE"
fi

# --- 5. Essential Settings Patching (.ini) ---
INI_FILE="$CONFIG_DIR/Server/${SERVER_NAME}.ini"
if [ -f "$INI_FILE" ]; then
    LogAction "Applying essential config patches (PVP, MaxPlayers, Minimap)"
    sed -i "s/^PVP=.*/PVP=${PVP:-true}/" "$INI_FILE"
    sed -i "s/^MaxPlayers=.*/MaxPlayers=${MAX_PLAYERS:-32}/" "$INI_FILE"
    sed -i "s/^AllowMiniMap=.*/AllowMiniMap=${ALLOW_MINIMAP:-true}/" "$INI_FILE"
    sed -i "s/^RCONPassword=.*/RCONPassword=${RCON_PASSWORD}/" "$INI_FILE"
    sed -i "s/^RCONEnabled=.*/RCONEnabled=true/" "$INI_FILE"
fi

# --- 6. Graceful Shutdown (RCON Save & Quit) ---
term_handler() {
    LogWarn "Stop signal received! Executing graceful shutdown..."
    rcon-cli -a 127.0.0.1:${RCON_PORT:-27015} -p "$RCON_PASSWORD" "save"
    rcon-cli -a 127.0.0.1:${RCON_PORT:-27015} -p "$RCON_PASSWORD" "quit"
    sleep 10
    LogSuccess "Server shut down cleanly."
    exit 0
}
trap 'term_handler' SIGTERM

# --- 7. Execution ---
LogSuccess "Launching Project Zomboid Dedicated Server!"
su - steam -c "/project-zomboid/ProjectZomboid64 -batchmode \
    -cachedir=$CONFIG_DIR \
    -adminusername $ADMIN_USERNAME \
    -adminpassword $ADMIN_PASSWORD \
    -port $DEFAULT_PORT \
    -servername $SERVER_NAME \
    $EXTRA_FLAGS" &

killpid="$!"
wait "$killpid"