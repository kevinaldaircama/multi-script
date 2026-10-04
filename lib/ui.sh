#!/bin/bash

# =========================================================
#             KEVINTECH MULTI SCRIPT
#                  UI SYSTEM
# =========================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# =========================================================
# CABECERA PREMIUM
# =========================================================

mv_brand_header() {

    local TITLE="$*"

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🛡️ KEVINTECH MULTI SCRIPT${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}HWID MANAGEMENT${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} ${YELLOW}${BOLD}%-58s${RESET} ${CYAN}║${RESET}\n" "$TITLE"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# =========================================================
# LÍNEA
# =========================================================

mv_line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

# =========================================================
# PAUSA
# =========================================================

mv_pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}