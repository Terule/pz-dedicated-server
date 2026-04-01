#!/bin/bash

# --- Definições de Cores para Logs ---
export RESET='\033[0m'
export RedBold='\033[1;31m'
export GreenBold='\033[1;32m'
export YellowBold='\033[1;33m'
export CyanBold='\033[1;36m'

LogAction() { printf "${CyanBold}==== %s ====${RESET}\n" "$1"; }
LogSuccess() { printf "${GreenBold}%s${RESET}\n" "$1"; }
LogWarn() { printf "${YellowBold}%s${RESET}\n" "$1"; }
LogError() { printf "${RedBold}%s${RESET}\n" "$1"; }

# --- Exibir Branding do Projeto ---
if [ -f "/home/steam/server/branding" ]; then
    cat /home/steam/server/branding
    printf "${CyanBold}Desenvolvido por Terule | IG: @aguiar_fael | GitHub: https://github.com/Terule${RESET}\n\n"
fi

# --- 1. Mapeamento de Usuário (PUID/PGID) ---
if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    LogAction "Sincronizando permissões do container com o host (PUID:$PUID PGID:$PGID)"
    groupmod -o -g "$PGID" steam
    usermod -o -u "$PUID" steam
fi
chown -R steam:steam /project-zomboid /project-zomboid-config /home/steam/

# --- 2. Verificação de Segurança do Admin ---
if [ -z "${ADMIN_PASSWORD}" ] || [ "${ADMIN_PASSWORD}" == "admin" ] || [ "${ADMIN_PASSWORD}" == "CHANGEME" ]; then
    LogWarn "AVISO DE SEGURANÇA: ADMIN_PASSWORD está fraca ou não definida!"
fi

# --- 3. Lógica de Update e Proteção de Save ---
# Impede atualização acidental da 42.15 para 42.16+
if [ "$SERVER_BRANCH" == "outdatedunstable" ]; then
    LogWarn "!!! OUTDATEDUNSTABLE (42.15) DETECTADO !!!"
    LogWarn "Updates automáticos desativados para proteger a compatibilidade do seu save."
    UPDATE_ON_START="false"
fi

if [ "$UPDATE_ON_START" = "true" ] || [ ! -f "/project-zomboid/ProjectZomboid64" ]; then
    LogAction "Atualizando arquivos do jogo (Branch: ${SERVER_BRANCH:-Stable})..."
    if [ -n "${SERVER_BRANCH}" ]; then
        envsubst < /home/steam/server/scripts/install_version.scmd > /tmp/run.scmd
    else
        cp /home/steam/server/scripts/install.scmd /tmp/run.scmd
    fi
    su - steam -c "${STEAMCMD_PATH:-/usr/bin/steamcmd} +runscript /tmp/run.scmd"
fi

# --- 4. Gestão de Memória (Patch no JSON) ---
JSON_FILE="/project-zomboid/ProjectZomboid64.json"
if [ -f "$JSON_FILE" ]; then
    LogAction "Aplicando patch de memória para ${MEMORY_XMX_GB}GB"
    su - steam -c "jq \".vmArgs |= map(if startswith(\\\"-Xmx\\\") then \\\"-Xmx${MEMORY_XMX_GB}G\\\" else . end)\" $JSON_FILE > $JSON_FILE.tmp && mv $JSON_FILE.tmp $JSON_FILE"
fi

# --- 5. Patch de Configurações (.ini e SandboxVars.lua) ---
INI_FILE="$CONFIG_DIR/Server/${SERVER_NAME}.ini"
SANDBOX_FILE="$CONFIG_DIR/Server/${SERVER_NAME}_SandboxVars.lua"

if [ -f "$INI_FILE" ]; then
    LogAction "Aplicando patches no arquivo .ini"
    # Configurações base
    sed -i "s/^PVP=.*/PVP=${PVP:-false}/" "$INI_FILE"
    sed -i "s/^MaxPlayers=.*/MaxPlayers=${MAX_PLAYERS:-10}/" "$INI_FILE"
    sed -i "s/^RCONPassword=.*/RCONPassword=${RCON_PASSWORD}/" "$INI_FILE"
    sed -i "s/^RCONEnabled=.*/RCONEnabled=true/" "$INI_FILE"
    sed -i "s/^Password=.*/Password=${SERVER_PASSWORD}/" "$INI_FILE"
    sed -i "s/^Public=.*/Public=${PUBLIC:-false}/" "$INI_FILE"
    
    # Configurações de exibição e privacidade solicitadas
    sed -i "s/^MouseOverToSeeDisplayName=.*/MouseOverToSeeDisplayName=${MOUSE_OVER_DISPLAY_NAME:-false}/" "$INI_FILE"
    sed -i "s/^DisplayUserName=.*/DisplayUserName=${DISPLAY_USER_NAME:-false}/" "$INI_FILE"
    sed -i "s/^ShowFirstAndLastName=.*/ShowFirstAndLastName=${SHOW_FIRST_LAST_NAME:-true}/" "$INI_FILE"
    sed -i "s/^SneakModeHideFromOtherPlayers=.*/SneakModeHideFromOtherPlayers=${SNEAK_HIDE_PLAYERS:-false}/" "$INI_FILE"
    sed -i "s/^MapRemotePlayerVisibility=.*/MapRemotePlayerVisibility=${MAP_REMOTE_VISIBILITY:-3}/" "$INI_FILE"
fi

if [ -f "$SANDBOX_FILE" ]; then
    LogAction "Aplicando patches no SandboxVars.lua"
    # Patch para AllowMiniMap (dentro da tabela Map no arquivo Lua)
    sed -i "s/AllowMiniMap = .*/AllowMiniMap = ${ALLOW_MINIMAP:-true},/" "$SANDBOX_FILE"
fi

# --- 6. Desligamento Gracioso (RCON Save & Quit) ---
term_handler() {
    LogWarn "Sinal de interrupção recebido! Executando shutdown gracioso..."
    rcon-cli -a 127.0.0.1:${RCON_PORT:-27015} -p "$RCON_PASSWORD" "save"
    rcon-cli -a 127.0.0.1:${RCON_PORT:-27015} -p "$RCON_PASSWORD" "quit"
    sleep 10
    LogSuccess "Servidor desligado com sucesso."
    exit 0
}
trap 'term_handler' SIGTERM

# --- 7. Execução do Servidor ---
LogSuccess "Iniciando Project Zomboid Dedicated Server!"
su - steam -c "/project-zomboid/ProjectZomboid64 -batchmode \
    -cachedir=$CONFIG_DIR \
    -adminusername \"$ADMIN_USERNAME\" \
    -adminpassword \"$ADMIN_PASSWORD\" \
    -port $DEFAULT_PORT \
    -servername $SERVER_NAME \
    $EXTRA_FLAGS" &

killpid="$!"
wait "$killpid"