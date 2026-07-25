#!/bin/bash

# Função para verificar se o CheckUser está instalado
check_installed() {
    if [ -f "/usr/lib/chall/chall.sh" ]; then
        return 0  # Já instalado
    else
        return 1  # Não instalado
    fi
}

# Limpa a tela e exibe o menu
show_menu() {
    clear
    echo -e "\033[46;1;37m              ★ MENU CHECKUSER ★               \033[0m"
    echo -e "\033[01;31m\033[0m"
    echo -e "\033[01;31m\033[1;31m\033[1;34m[\033[1;37m 01 •\033[1;34m]\033[1;37m ➤  \033[1;33mINSTALAR CHECKUSER MULTI-APPS\033[0m"
    echo -e "\033[01;31m\033[1;31m\033[1;34m[\033[1;37m 02 •\033[1;34m]\033[1;37m ➤  \033[1;33mINSTALAR CHECKUSER DTUNNEL\033[0m"
    echo -e "\033[01;31m\033[1;31m\033[1;34m[\033[1;37m 03 •\033[1;34m]\033[1;37m ➤  \033[1;33mINSTALAR CHECKUSER DTUNNEL-GO\033[0m"
    echo -e "\033[01;31m\033[1;31m\033[1;34m[\033[1;37m 04 •\033[1;34m]\033[1;37m ➤  \033[1;33mINSTALAR SUSPENDER USUÁRIO\033[0m"
    echo -e "\033[01;31m\033[1;31m\033[1;34m[\033[1;37m 00 •\033[1;34m]\033[1;37m ➤  \033[1;33mVOLTAR  \033[1;32m<\033[1;33m<\033[1;31m< \033[0m"
    echo -e "\033[01;31m\033[0m"
    echo -e "\033[0;36m░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░░★░\033[0m"
}

# Exibe o menu e lê a escolha do usuário
get_user_choice() {
    tput civis
    echo -ne "\033[1;31m➤ \033[1;32mESCOLHA OPÇÃO DESEJADA\033[1;33m\033[1;31m\033[1;37m:"; read x
    tput cnorm
}

# Executa a escolha do usuário
execute_choice() {
    case $x in
    1 | 01)
        if check_installed; then
            chall # Já instalado, executar o sistema chall
        else
            bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/instcheck.sh) && chall    
        fi
        ;;
    2 | 02)
        bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/DTCheckUser/master/install.sh)
        ;;
    3 | 03)
        bash <(curl -sL https://n9.cl/yo2nc)
        ;;
    4 | 04)
        suspenderusuario.sh
        ;;
    0 | 00)
        clear
        menu # Certifique-se de que a função `menu` está definida em outro lugar
        ;;
    *)
        echo -e "\033[1;31mOpcao invalida!\033[0m"
        ;;
    esac
}

# Executa o script
show_menu
get_user_choice
execute_choice
sleep 2
