#!/bin/bash
#========================================
# KevinTech Multi Script
# OpenVPN Manager
# Basado en Nyr OpenVPN Installer
#==================================================
  BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"
if [[ -z "$SERVER_DOMAIN" ]]; then
    echo "❌ No hay un dominio configurado."
    echo "👉 Configúralo primero desde el menú principal."
    exit 1
fi
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
RESET="\e[0m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"

# Verificar que se ejecute con bash
if readlink /proc/$$/exe | grep -q "dash"; then  
	echo "❌ Este instalador debe ejecutarse con bash y no con sh."  
	exit  
fi  
  
# Discard stdin. Needed when running from an one-liner which includes a newline  
read -N 999999 -t 0.001  
  

#==================================================
# Detectar Ubuntu (todas las versiones)
#==================================================
source /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
    clear
    echo "❌ KevinTech OpenVPN solo es compatible con Ubuntu."
    exit 1
fi

group_name="nogroup"
  
# Detect environments where $PATH does not include the sbin directories  
if ! grep -q sbin <<< "$PATH"; then  
	echo "❌ El PATH no incluye sbin."
echo "👉 Ejecuta: su -"  
	exit  
fi  
  
if [[ "$EUID" -ne 0 ]]; then  
	echo "❌ Debes ejecutar este script como root."  
	exit  
fi  
  
if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then  
	echo "❌ El dispositivo TUN no está habilitado."
echo "👉 Activa TUN antes de instalar OpenVPN."
	exit  
fi  
  
new_client () {  
	# Generates the custom client.ovpn  
	{  
	cat /etc/openvpn/server/client-common.txt  
	echo "<ca>"  
	cat /etc/openvpn/server/easy-rsa/pki/ca.crt  
	echo "</ca>"  
	echo "<cert>"  
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt  
	echo "</cert>"  
	echo "<key>"  
	cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key  
	echo "</key>"  
	echo "<tls-crypt>"  
	sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key  
	echo "</tls-crypt>"  
	} > ~/"$client".ovpn  
}  
  
if [[ ! -e /etc/openvpn/server/server.conf ]]; then  
	# Detect some Debian minimal setups where neither wget nor curl are installed  
	if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then  
		echo "📦 Wget no está instalado."
read -n1 -r -p "Presiona cualquier tecla para instalarlo..."
		apt-get update  
		apt-get install -y wget  
	fi  
	clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA} KevinTech Multi Script${RESET}"
echo -e "${WHITE} OpenVPN Manager${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
	# If system has a single IPv4, it is selected automatically. Else, ask the user  
	if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then  
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')  
	else  
		number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')  
		echo  
		echo "Which IPv4 address should be used?"  
		ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '  
		read -p "IPv4 address [1]: " ip_number  
		until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do  
			echo "$ip_number: invalid selection."  
			read -p "IPv4 address [1]: " ip_number  
		done  
		[[ -z "$ip_number" ]] && ip_number="1"  
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)  
	fi  
	# If system has a single IPv6, it is selected automatically  
	if [[ $(ip -6 addr | grep -c 'inet6 [23]') -eq 1 ]]; then  
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')  
	fi  
	# If system has multiple IPv6, ask the user to select one  
	if [[ $(ip -6 addr | grep -c 'inet6 [23]') -gt 1 ]]; then  
		number_of_ip6=$(ip -6 addr | grep -c 'inet6 [23]')  
		echo  
		echo "Which IPv6 address should be used?"  
		ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | nl -s ') '  
		read -p "IPv6 address [1]: " ip6_number  
		until [[ -z "$ip6_number" || "$ip6_number" =~ ^[0-9]+$ && "$ip6_number" -le "$number_of_ip6" ]]; do  
			echo "$ip6_number: invalid selection."  
			read -p "IPv6 address [1]: " ip6_number  
		done  
		[[ -z "$ip6_number" ]] && ip6_number="1"  
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | sed -n "$ip6_number"p)  
	fi  
	protocol="tcp"
	port="1194"
	echo  
	echo "Nombre del primer cliente:"  
	read -p "Name [client]: " unsanitized_client  
	# Allow a limited set of characters to avoid conflicts  
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")  
	[[ -z "$client" ]] && client="client"  
	echo  
	echo "✅ Todo listo para instalar OpenVPN."  
	
	read -n1 -r -p "Presiona cualquier tecla para continuar..."  
	# If running inside a container, disable LimitNPROC to prevent conflicts   
	if systemd-detect-virt -cq; then  
		mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/null  
		echo "[Service]  
LimitNPROC=infinity" > /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf  
	fi  
	apt-get update
apt-get install -y --no-install-recommends \
openvpn \
openssl \
ca-certificates \
iptables \
tar
	
	# Get easy-rsa  
	easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.1/EasyRSA-3.2.1.tgz'  
	mkdir -p /etc/openvpn/server/easy-rsa/  
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1  
	chown -R root:root /etc/openvpn/server/easy-rsa/  
	cd /etc/openvpn/server/easy-rsa/  
	# Create the PKI, set up the CA and the server and client certificates  
	./easyrsa --batch init-pki  
	./easyrsa --batch build-ca nopass  
	./easyrsa --batch --days=3650 build-server-full server nopass  
	./easyrsa --batch --days=3650 build-client-full "$client" nopass  
	./easyrsa --batch --days=3650 gen-crl  
	# Move the stuff we need  
	cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server  
	# CRL is read with each client connection, while OpenVPN is dropped to nobody  
	chown nobody:"$group_name" /etc/openvpn/server/crl.pem  
	# Without +x in the directory, OpenVPN can't run a stat() on the CRL file  
	chmod o+x /etc/openvpn/server/  
	# Generate key for tls-crypt  
	openvpn --genkey secret /etc/openvpn/server/tc.key  
	# Create the DH parameters file using the predefined ffdhe2048 group  
	echo '-----BEGIN DH PARAMETERS-----  
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz  
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a  
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7  
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi  
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD  
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==  
-----END DH PARAMETERS-----' > /etc/openvpn/server/dh.pem  
	# Generate server.conf  
	echo "port $port  
proto $protocol  
dev tun  
ca ca.crt  
cert server.crt  
key server.key  
dh dh.pem  
auth SHA512  
tls-crypt tc.key  
topology subnet  
server 10.8.0.0 255.255.255.0" > /etc/openvpn/server/server.conf  
	# IPv6  
	if [[ -z "$ip6" ]]; then  
		echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf  
	else  
		echo 'server-ipv6 fddd:1194:1194:1194::/64' >> /etc/openvpn/server/server.conf  
		echo 'push "redirect-gateway def1 ipv6 bypass-dhcp"' >> /etc/openvpn/server/server.conf  
	fi  
	echo 'ifconfig-pool-persist ipp.txt' >> /etc/openvpn/server/server.conf  
	# DNS  
	echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server/server.conf
echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server/server.conf
	echo 'push "block-outside-dns"' >> /etc/openvpn/server/server.conf  
	echo "keepalive 10 120  
float  
cipher AES-256-CBC  
user nobody  
group $group_name  
persist-key  
persist-tun  
status openvpn-status.log  
management localhost 7505  
verb 3  
crl-verify crl.pem  
client-to-client    
username-as-common-name
plugin /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so login
duplicate-cn" >> /etc/openvpn/server/server.conf  
	if [[ "$protocol" = "udp" ]]; then  
		echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf  
	fi  
	# Enable net.ipv4.ip_forward for the system  
	echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf  
	# Enable without waiting for a reboot or service restart  
	echo 1 > /proc/sys/net/ipv4/ip_forward  
	if [[ -n "$ip6" ]]; then  
		# Enable net.ipv6.conf.all.forwarding for the system  
		echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-openvpn-forward.conf  
		# Enable without waiting for a reboot or service restart  
		echo 1 > /proc/sys/net/ipv6/conf/all/forwarding  
	fi   
		# Create a service to set up persistent iptables rules  
		iptables_path=$(command -v iptables)  
		ip6tables_path=$(command -v ip6tables)  
		# nf_tables is not available as standard in OVZ kernels. So use iptables-legacy  
		# if we are in OVZ, with a nf_tables backend and iptables-legacy is available.  
		if [[ $(systemd-detect-virt) == "openvz" ]] && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then  
			iptables_path=$(command -v iptables-legacy)  
			ip6tables_path=$(command -v ip6tables-legacy)  
		fi  
		echo "[Unit]  
Before=network.target  
[Service]  
Type=oneshot  
ExecStart=$iptables_path -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip  
ExecStart=$iptables_path -I INPUT -p $protocol --dport $port -j ACCEPT  
ExecStart=$iptables_path -I FORWARD -s 10.8.0.0/24 -j ACCEPT  
ExecStart=$iptables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT  
ExecStop=$iptables_path -t nat -D POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip  
ExecStop=$iptables_path -D INPUT -p $protocol --dport $port -j ACCEPT  
ExecStop=$iptables_path -D FORWARD -s 10.8.0.0/24 -j ACCEPT  
ExecStop=$iptables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" > /etc/systemd/system/openvpn-iptables.service  
		if [[ -n "$ip6" ]]; then  
			echo "ExecStart=$ip6tables_path -t nat -A POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6  
ExecStart=$ip6tables_path -I FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT  
ExecStart=$ip6tables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT  
ExecStop=$ip6tables_path -t nat -D POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6  
ExecStop=$ip6tables_path -D FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT  
ExecStop=$ip6tables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" >> /etc/systemd/system/openvpn-iptables.service  
		fi  
		echo "RemainAfterExit=yes  
[Install]  
WantedBy=multi-user.target" >> /etc/systemd/system/openvpn-iptables.service  
		systemctl enable --now openvpn-iptables.service  
	fi  
	# client-common.txt is created so we have a template to add further users later  
	echo "client  
dev tun  
proto $protocol  
remote $SERVER_DOMAIN $port  
resolv-retry infinite  
nobind  
persist-key  
persist-tun  
remote-cert-tls server  
auth SHA512  
ignore-unknown-option block-outside-dns 
auth-user-pass
verb 3" > /etc/openvpn/server/client-common.txt  
	# Enable and start the OpenVPN service  
	systemctl enable --now openvpn-server@server.service  
	if [[ -f "$CONFIG" ]]; then
    sed -i '/^OPENVPN=/d' "$CONFIG"
    echo "OPENVPN=ON" >> "$CONFIG"
fi
	# Generates the custom client.ovpn  
	new_client  
	echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ OpenVPN instalado"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Dominio : $SERVER_DOMAIN"
echo "🔒 Puerto  : $port"
echo "👤 Cliente : $client"
echo "📄 Archivo : /root/$client.ovpn"
echo
echo "💡 Puedes crear más clientes desde el menú OpenVPN."
else  
	clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          KevinTech Multi Script${RESET}"
echo -e "${WHITE}             OPENVPN MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo -e " ${GREEN}[01]${RESET} 👤 Crear Cliente"
echo -e " ${GREEN}[02]${RESET} ❌ Revocar Cliente"
echo -e " ${GREEN}[03]${RESET} 🗑 Desinstalar OpenVPN"
echo -e " ${GREEN}[04]${RESET} 📊 Estado del Servicio"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e " ${GREEN}[00]${RESET} ↩ Regresar"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
read -rp " ► Opción: " option

until [[ "$option" =~ ^(0|1|2|3|4|01|02|03|04)$ ]]; do
    echo -e "${RED}❌ Opción inválida.${RESET}"
    read -rp " ► Opción: " option
done
	case "$option" in  
		1|01)  
			echo  
			echo "Introduce el nombre del cliente:"
read -p "Nombre: " unsanitized_client 
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")  
			while [[ -z "$client" || -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; do  
				echo "$client: invalid name."  
				read -p "Name: " unsanitized_client  
				client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")  
			done  
			cd /etc/openvpn/server/easy-rsa/  
			./easyrsa --batch --days=3650 build-client-full "$client" nopass  
			# Generates the custom client.ovpn  
			new_client  
			echo  
			echo "✅ Cliente creado correctamente."
echo "📄 Archivo: /root/$client.ovpn"
			exit  
		;;  
		2|02)  
			# This option could be documented a bit better and maybe even be simplified  
			# ...but what can I say, I want some sleep too  
			number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")  
			if [[ "$number_of_clients" = 0 ]]; then  
				echo  
				echo "❌ No existen clientes registrados."  
				exit  
			fi  
			echo  
			echo "Selecciona el cliente que deseas revocar:"  
			tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '  
			read -p "Cliente: " client_number  
			until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do  
				echo "$client_number: invalid selection."  
				read -p "Cliente: " client_number  
			done  
			client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)  
			echo  
			read -p "¿Revocar el cliente $client? [s/N]: " revoke  
			until [[ "$revoke" =~ ^[yYnN]*$ ]]; do  
				echo "$revoke: invalid selection."  
				read -p "¿Revocar el cliente $client? [s/N]: " revoke  
			done  
			if [[ "$revoke" =~ ^[sSyY]$ ]]; then  
				cd /etc/openvpn/server/easy-rsa/  
				./easyrsa --batch revoke "$client"  
				./easyrsa --batch --days=3650 gen-crl  
				rm -f /etc/openvpn/server/crl.pem  
				cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem  
				# CRL is read with each client connection, when OpenVPN is dropped to nobody  
				chown nobody:"$group_name" /etc/openvpn/server/crl.pem  
				echo  
				echo "✅ Cliente $client revocado correctamente."  
			else  
				echo  
				echo "❌ Operación cancelada."  
			fi  
			exit  
		;;  
		3|03)  
			echo  
			read -p "¿Deseas desinstalar OpenVPN? [s/N]: " remove  
			until [[ "$remove" =~ ^[yYnN]*$ ]]; do  
				echo "$remove: invalid selection."  
				read -p "¿Deseas desinstalar OpenVPN? [s/N]: " remove  
			done  
			if [[ "$remove" =~ ^[sSyY]$ ]]; then

    systemctl disable --now openvpn-iptables.service
    rm -f /etc/systemd/system/openvpn-iptables.service

    systemctl disable --now openvpn-server@server.service

    rm -rf /etc/openvpn/server

    apt-get remove --purge -y openvpn

    sed -i 's/^OPENVPN=.*/OPENVPN=OFF/' "$CONFIG"

    echo "OpenVPN eliminado."

else

    echo "Operación cancelada."

fi
			exit  
		;;  
	   4|04)
        systemctl status openvpn-server@server --no-pager
        read -n1 -r -p "Presione una tecla para continuar..."
        exec "$0"
    ;;

    0|00)
        exec bash "$BASE/protocolos/menu.sh"
    ;;
esac
fi
