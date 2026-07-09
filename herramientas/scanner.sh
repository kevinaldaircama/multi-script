#!/bin/bash

# Colores para el menú
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Banner Personalizado
mostrar_banner() {
    clear
    echo -e "${BLUE}======================================================${RESET}"
    echo -e "${GREEN}      privanox Scanner - Subdominios y CDN/WAF        ${RESET}"
    echo -e "${YELLOW}            By Kevin tech tutorials                  ${RESET}"
    echo -e "${BLUE}======================================================${RESET}"
    echo ""
}

# Función 0: Verificar e instalar dependencias
verificar_dependencias() {
    echo -e "${YELLOW}[*] Verificando dependencias necesarias...${RESET}"
    
    # Comprobar Go
    if ! command -v go &> /dev/null; then
        echo -e "${RED}[!] Go no está instalado. Iniciando instalación...${RESET}"
        sudo apt update && sudo apt install golang-go -y
    else
        echo -e "${GREEN}[+] Go detectado.${RESET}"
    fi

    # Comprobar Assetfinder
    if ! command -v assetfinder &> /dev/null; then
        echo -e "${RED}[!] Assetfinder no está instalado. Iniciando instalación...${RESET}"
        go install github.com/tomnomnom/assetfinder@latest
        sudo cp ~/go/bin/assetfinder /usr/local/bin/ 2>/dev/null
    else
        echo -e "${GREEN}[+] Assetfinder detectado.${RESET}"
    fi

    # Comprobar httpx
    if ! command -v httpx &> /dev/null; then
        echo -e "${RED}[!] httpx no está instalado. Iniciando instalación...${RESET}"
        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
        sudo cp ~/go/bin/httpx /usr/local/bin/ 2>/dev/null
    else
        echo -e "${GREEN}[+] httpx detectado.${RESET}"
    fi
    
    echo -e "${GREEN}[+] Entorno listo para trabajar.${RESET}"
    sleep 2
}

# Función 1: Buscar Subdominios
buscar_subdominios() {
    read -p "Introduce el dominio objetivo (ej. dominio.com): " dominio
    echo -e "${YELLOW}[*] Buscando subdominios con Assetfinder...${RESET}"
    
    assetfinder --subs-only $dominio | sort -u > "subdominios_$dominio.txt"
    total=$(wc -l < "subdominios_$dominio.txt")
    
    echo -e "${GREEN}[+] Búsqueda completada. Se encontraron $total subdominios.${RESET}"
    echo -e "${GREEN}[+] Guardados en: subdominios_$dominio.txt${RESET}"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función 2: Detectar Tecnologías y CDN
detectar_tecnologias() {
    read -p "Introduce el nombre del archivo con la lista de subdominios: " archivo
    
    if [ ! -f "$archivo" ]; then
        echo -e "${RED}[!] El archivo $archivo no existe.${RESET}"
        read -p "Presiona Enter para continuar..."
        return
    fi

    echo -e "${YELLOW}[*] Analizando servicios (Cloudflare, CloudFront, etc.) con httpx...${RESET}"
    cat "$archivo" | httpx -silent -status-code -ip -tech-detect -title | tee "resultados_tech_$archivo"
    
    echo ""
    echo -e "${GREEN}[+] Análisis completado. Resultados en: resultados_tech_$archivo${RESET}"
    read -p "Presiona Enter para continuar..."
}

# Función 3: Escaneo Completo
escaneo_completo() {
    read -p "Introduce el dominio objetivo (ej. dominio.com): " dominio
    echo -e "${YELLOW}[*] Paso 1: Buscando subdominios...${RESET}"
    assetfinder --subs-only $dominio | sort -u > "subdominios_$dominio.txt"
    
    total=$(wc -l < "subdominios_$dominio.txt")
    echo -e "${GREEN}[+] Se encontraron $total subdominios.${RESET}"
    
    echo -e "${YELLOW}[*] Paso 2: Analizando tecnologías y detectando CDN/WAF...${RESET}"
    cat "subdominios_$dominio.txt" | httpx -silent -status-code -ip -tech-detect -title | tee "escaneo_completo_$dominio.txt"
    
    echo -e "${GREEN}[+] Proceso finalizado. Resultados guardados en: escaneo_completo_$dominio.txt${RESET}"
    read -p "Presiona Enter para continuar..."
}

# Ejecutar verificación al iniciar
verificar_dependencias

# Menú Principal
while true; do
    mostrar_banner
    echo -e "Selecciona una opción:"
    echo -e "  ${GREEN}1)${RESET} Solo buscar subdominios (Assetfinder)"
    echo -e "  ${GREEN}2)${RESET} Detectar CDN/WAF en una lista existente (httpx)"
    echo -e "  ${GREEN}3)${RESET} Escaneo Completo Automático (Recomendado)"
    echo -e "  ${RED}4)${RESET} Salir"
    echo ""
    read -p "Opción: " opcion

    case $opcion in
        1) buscar_subdominios ;;
        2) detectar_tecnologias ;;
        3) escaneo_completo ;;
        4) echo -e "${YELLOW}¡Hasta luego!${RESET}"; exit 0 ;;
        *) echo -e "${RED}[!] Opción no válida.${RESET}"; sleep 1 ;;
    esac
done
