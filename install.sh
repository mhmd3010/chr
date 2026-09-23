#!/bin/bash
set -e

# Styling & Colors (btop-inspired theme)
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[38;5;51m"
C_GREEN="\033[38;5;48m"
C_YELLOW="\033[38;5;220m"
C_RED="\033[38;5;196m"
C_MAGENTA="\033[38;5;198m"
C_GRAY="\033[38;5;242m"

if [ "$EUID" -ne 0 ]; then
    echo -e "${C_RED}Error:${C_RESET} This script must be run as root." >&2
    exit 1
fi

# Detect hardware specs for stats card
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' | cut -c1-26)
[ -z "$CPU_MODEL" ] && CPU_MODEL="Generic x86_64"
CPU_CORES=$(nproc 2>/dev/null || echo "1")
MEM_TOTAL=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
[ -z "$MEM_TOTAL" ] && MEM_TOTAL="N/A"

if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_TAG="${C_GREEN}ENABLED (host)${C_RESET}"
    KVM_OPTS="-enable-kvm -cpu host"
else
    KVM_TAG="${C_YELLOW}EMULATION (kvm64)${C_RESET}"
    KVM_OPTS="-cpu kvm64"
fi

# Banner & System Stats
clear 2>/dev/null || true
echo -e "${C_CYAN}╭──────────────────────────────────────────────────────────────╮${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD}${C_MAGENTA}  __  __ _ _             _____ _ _      ${C_CYAN}CHR INSTALLER          │${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD}${C_MAGENTA} |  \/  (_) |           |_   _(_) |     ${C_GRAY}Debian QEMU Engine     │${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD}${C_MAGENTA} | \  / |_| | ___ __ ___  | |  _| | __  ${C_GRAY}MikroTik RouterOS      │${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD}${C_MAGENTA} | |\/| | | |/ / '__/ _ \ | | | | |/ /                         │${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD}${C_MAGENTA} |_|  |_|_|_|\_\_|  \___/ |_| |_|_|\_\                         │${C_RESET}"
echo -e "${C_CYAN}├─────────────────────────────┬────────────────────────────────┤${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD} HOST HARDWARE               ${C_CYAN}│${C_BOLD} ACCELERATION                   ${C_CYAN}│${C_RESET}"
printf "${C_CYAN}│${C_RESET} CPU: %-23s ${C_CYAN}│${C_RESET} KVM: %-35b ${C_CYAN}│\n" "$CPU_MODEL" "$KVM_TAG"
printf "${C_CYAN}│${C_RESET} RAM: %-7s Cores: %-7s ${C_CYAN}│${C_RESET} Alloc: 512M RAM / 2 vCPUs     ${C_CYAN}│\n" "$MEM_TOTAL" "$CPU_CORES"
echo -e "${C_CYAN}╰─────────────────────────────┴────────────────────────────────╯${C_RESET}"
echo ""
echo -e " ${C_BOLD}MENU OPTIONS:${C_RESET}"
echo -e "   ${C_CYAN}1)${C_RESET} Install MikroTik CHR"
echo -e "   ${C_YELLOW}2)${C_RESET} Uninstall & Purge"
echo -e "   ${C_RED}3)${C_RESET} Exit"
echo ""
read -p " Select an option [1-3]: " OPTION

draw_progress() {
    local step=$1
    local total=6
    local desc=$2
    local percent=$(( (step * 100) / total ))
    local filled=$(( (percent * 20) / 100 ))
    local empty=$(( 20 - filled ))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="■"; done
    local blank=""
    for ((i=0; i<empty; i++)); do blank+="□"; done
    
    echo -e "\n${C_CYAN}[${C_GREEN}${bar}${C_GRAY}${blank}${C_CYAN}] ${C_BOLD}${percent}%${C_RESET} ${C_BOLD}[${step}/${total}]${C_RESET} ${desc}"
}

if [ "$OPTION" = "2" ]; then
    echo -e "\n${C_YELLOW}╭──────────────────────────────────────────────────────────────╮${C_RESET}"
    echo -e "${C_YELLOW}│${C_BOLD} Uninstallation in progress...                                ${C_YELLOW}│${C_RESET}"
    echo -e "${C_YELLOW}╰──────────────────────────────────────────────────────────────╯${C_RESET}"
    
    systemctl stop mikrotik-chr.service || true
    systemctl disable mikrotik-chr.service || true
    rm -f /etc/systemd/system/mikrotik-chr.service
    systemctl daemon-reload
    rm -rf /opt/chr
    rm -f /etc/qemu-ifup
    
    # Remove firewall rules
    iptables -t nat -D POSTROUTING -s 100.64.0.0/24 -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80 2>/dev/null || true
    ip route del 10.100.0.0/24 via 100.64.0.2 2>/dev/null || true
    netfilter-persistent save || true

    echo -e "\n${C_GREEN}✔ Uninstallation complete and clean!${C_RESET}\n"
    exit 0
elif [ "$OPTION" = "3" ]; then
    echo -e "\n${C_GRAY}Action cancelled.${C_RESET}\n"
    exit 0
elif [ "$OPTION" != "1" ]; then
    echo -e "\n${C_RED}Invalid option selected. Exiting.${C_RESET}\n"
    exit 1
fi

echo -e "\n${C_CYAN}╭──────────────────────────────────────────────────────────────╮${C_RESET}"
echo -e "${C_CYAN}│${C_BOLD} Starting Deployment                                          ${C_CYAN}│${C_RESET}"
echo -e "${C_CYAN}╰──────────────────────────────────────────────────────────────╯${C_RESET}"

# 1. Update and install dependencies
draw_progress 1 "Installing dependencies (qemu, iptables, bridge tools)..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qemu-system-x86 qemu-utils uml-utilities iproute2 iptables iptables-persistent

# 2. Setup CHR Directory and Image
draw_progress 2 "Preparing CHR image in /opt/chr/..."
mkdir -p /opt/chr

if [ -f "chr.qcow2" ]; then
    cp chr.qcow2 /opt/chr/chr.qcow2
else
    echo -e "\n${C_RED}Error: chr.qcow2 not found! Make sure you are inside the installer folder.${C_RESET}"
    exit 1
fi

# 3. Enable IP Forwarding
draw_progress 3 "Enabling host IPv4 packet forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# 4. Setup qemu-ifup script
draw_progress 4 "Configuring TAP virtual network interface..."
cat << 'EOF' > /etc/qemu-ifup
#!/bin/sh
ip link set $1 up
ip addr add 100.64.0.1/24 dev $1
ip route add 10.100.0.0/24 via 100.64.0.2 || true
EOF
chmod +x /etc/qemu-ifup

# 5. Setup Systemd Service
draw_progress 5 "Generating systemd background service..."

# Generate a random MAC address so each VPS has a unique MAC
RANDOM_MAC=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

cat << EOF > /etc/systemd/system/mikrotik-chr.service
[Unit]
Description=MikroTik CHR
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/qemu-system-x86_64 -nographic -m 512M -smp 2 $KVM_OPTS -machine pc -netdev tap,id=n1,ifname=tap0,script=/etc/qemu-ifup,downscript=no -device virtio-net-pci,netdev=n1,mac=$RANDOM_MAC -drive file=/opt/chr/chr.qcow2,if=ide,format=qcow2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mikrotik-chr.service >/dev/null 2>&1

# 6. Setup IPTables rules
draw_progress 6 "Configuring NAT and firewall forwarding rules..."
iptables -t nat -D POSTROUTING -s 100.64.0.0/24 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80 2>/dev/null || true

iptables -t nat -A POSTROUTING -s 100.64.0.0/24 -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp --dport 4443 -j DNAT --to-destination 100.64.0.2:443
iptables -t nat -A PREROUTING -p tcp --dport 7001 -j DNAT --to-destination 100.64.0.2:8291
iptables -t nat -A PREROUTING -p tcp --dport 7002 -j DNAT --to-destination 100.64.0.2:80

# Allow traffic through the FORWARD chain
iptables -D FORWARD -i tap0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o tap0 -j ACCEPT 2>/dev/null || true
iptables -I FORWARD -i tap0 -j ACCEPT
iptables -I FORWARD -o tap0 -j ACCEPT

# Add static route to VPN pool immediately
ip route add 10.100.0.0/24 via 100.64.0.2 2>/dev/null || true

netfilter-persistent save >/dev/null 2>&1

echo ""
echo -e "${C_GREEN}╭──────────────────────────────────────────────────────────────╮${C_RESET}"
echo -e "${C_GREEN}│${C_BOLD} ✔ MikroTik CHR Installation Complete                         ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}├──────────────────────────────────────────────────────────────┤${C_RESET}"
echo -e "${C_GREEN}│${C_RESET}  Status:   ${C_GREEN}● Active (Running in background)${C_RESET}                  ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}│${C_RESET}  Winbox:   ${C_CYAN}port 7001${C_RESET} (forwarded to 100.64.0.2:8291)           ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}│${C_RESET}  WebFig:   ${C_CYAN}port 7002${C_RESET} (forwarded to 100.64.0.2:80)             ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}│${C_RESET}  SSTP VPN: ${C_CYAN}port 4443${C_RESET} (forwarded to 100.64.0.2:443)            ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}├──────────────────────────────────────────────────────────────┤${C_RESET}"
echo -e "${C_GREEN}│${C_GRAY}  Please check README.md for the initial one-time console IP  ${C_GREEN}│${C_RESET}"
echo -e "${C_GREEN}╰──────────────────────────────────────────────────────────────╯${C_RESET}"
echo ""
