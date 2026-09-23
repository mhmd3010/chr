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
C_BLINK="\033[5m"

if [ "$EUID" -ne 0 ]; then
    echo -e "${C_RED}Error:${C_RESET} This script must be run as root." >&2
    exit 1
fi

# Terminal width calculation
WIDTH=$(tput cols 2>/dev/null || echo 80)
[ -z "$WIDTH" ] || [ "$WIDTH" -lt 64 ] && WIDTH=80

repeat_char() {
    local char="$1"
    local count="$2"
    [ "$count" -le 0 ] && return
    printf "%*s" "$count" "" | tr ' ' "$char"
}

draw_box_top() {
    local color="$1"
    local title="$2"
    local inner_w=$(( WIDTH - 2 ))
    if [ -n "$title" ]; then
        local t_len=${#title}
        local fill_w=$(( inner_w - t_len - 3 ))
        local fill_str=$(repeat_char "─" "$fill_w")
        echo -e "${color}╭─ ${C_BOLD}${title}${C_RESET}${color} ${fill_str}╮${C_RESET}"
    else
        local fill_str=$(repeat_char "─" "$inner_w")
        echo -e "${color}╭${fill_str}╮${C_RESET}"
    fi
}

draw_box_sep() {
    local color="$1"
    local inner_w=$(( WIDTH - 2 ))
    local fill_str=$(repeat_char "─" "$inner_w")
    echo -e "${color}├${fill_str}┤${C_RESET}"
}

draw_box_bottom() {
    local color="$1"
    local inner_w=$(( WIDTH - 2 ))
    local fill_str=$(repeat_char "─" "$inner_w")
    echo -e "${color}╰${fill_str}╯${C_RESET}"
}

draw_box_line() {
    local color="$1"
    local text="$2"
    local plain_text
    plain_text=$(echo -e "$text" | sed -E "s/\x1B\[[0-9;]*[a-zA-Z]//g")
    local len=${#plain_text}
    local pad=$(( WIDTH - 4 - len ))
    [ "$pad" -lt 0 ] && pad=0
    local pad_str
    pad_str=$(repeat_char " " "$pad")
    echo -e "${color}│${C_RESET} ${text}${pad_str} ${color}│${C_RESET}"
}

draw_progress() {
    local step=$1
    local total=6
    local desc=$2
    local percent=$(( (step * 100) / total ))
    local bar_len=$(( WIDTH - 40 ))
    [ "$bar_len" -lt 15 ] && bar_len=15
    [ "$bar_len" -gt 45 ] && bar_len=45
    local filled=$(( (percent * bar_len) / 100 ))
    local empty=$(( bar_len - filled ))
    
    local bar=$(repeat_char "■" "$filled")
    local blank=$(repeat_char "□" "$empty")
    
    echo -e "\n${C_CYAN}[${C_GREEN}${bar}${C_GRAY}${blank}${C_CYAN}] ${C_BOLD}${percent}%${C_RESET} ${C_BOLD}[${step}/${total}]${C_RESET} ${desc}"
}

# Detect hardware specs
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' | cut -c1-30)
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
draw_box_top "$C_CYAN" "MIKROTIK CHR INSTALLER"
draw_box_line "$C_CYAN" "${C_BOLD}${C_MAGENTA}  __  __ _ _             _____ _ _      ${C_CYAN}Debian QEMU Edition${C_RESET}"
draw_box_line "$C_CYAN" "${C_BOLD}${C_MAGENTA} |  \/  (_) |           |_   _(_) |     ${C_GRAY}RouterOS Automation${C_RESET}"
draw_box_line "$C_CYAN" "${C_BOLD}${C_MAGENTA} | \  / |_| | ___ __ ___  | |  _| | __  ${C_GRAY}Version 1.5${C_RESET}"
draw_box_line "$C_CYAN" "${C_BOLD}${C_MAGENTA} | |\/| | | |/ / '__/ _ \ | | | | |/ /  ${C_GRAY}https://github.com/mhmd3010/chr${C_RESET}"
draw_box_line "$C_CYAN" "${C_BOLD}${C_MAGENTA} |_|  |_|_|_|\_\_|  \___/ |_| |_|_|\_\ ${C_RESET}"
draw_box_sep "$C_CYAN"
draw_box_line "$C_CYAN" "${C_BOLD}CPU Model:${C_RESET} $CPU_MODEL (${CPU_CORES} cores)"
draw_box_line "$C_CYAN" "${C_BOLD}Host Memory:${C_RESET} $MEM_TOTAL total    ${C_BOLD}Assigned VM:${C_RESET} 512M RAM / 2 vCPUs"
draw_box_line "$C_CYAN" "${C_BOLD}Virtualization:${C_RESET} $KVM_TAG"
draw_box_bottom "$C_CYAN"

echo ""
echo -e " ${C_BOLD}MENU OPTIONS:${C_RESET}"
echo -e "   ${C_CYAN}1)${C_RESET} Install MikroTik CHR"
echo -e "   ${C_YELLOW}2)${C_RESET} Uninstall CHR (Keep packages)"
echo -e "   ${C_RED}3)${C_RESET} Uninstall & Purge (Remove QEMU & packages)"
echo -e "   ${C_GRAY}4)${C_RESET} Exit"
echo ""
read -p " Select an option [1-4]: " OPTION

if [ "$OPTION" = "2" ] || [ "$OPTION" = "3" ]; then
    echo ""
    draw_box_top "$C_YELLOW" "UNINSTALLATION"
    draw_box_line "$C_YELLOW" "Stopping services and cleaning configurations..."
    draw_box_bottom "$C_YELLOW"
    
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

    if [ "$OPTION" = "3" ]; then
        echo -e "\n${C_RED}Purging QEMU and related dependencies...${C_RESET}"
        DEBIAN_FRONTEND=noninteractive apt-get purge -y qemu-system-x86 qemu-utils uml-utilities
        apt-get autoremove -y -qq
        echo -e "${C_GREEN}✔ Dependencies purged successfully.${C_RESET}"
    fi

    echo -e "\n${C_GREEN}✔ Uninstallation complete!${C_RESET}\n"
    exit 0
elif [ "$OPTION" = "4" ]; then
    echo -e "\n${C_GRAY}Action cancelled.${C_RESET}\n"
    exit 0
elif [ "$OPTION" != "1" ]; then
    echo -e "\n${C_RED}Invalid option selected. Exiting.${C_RESET}\n"
    exit 1
fi

echo ""
draw_box_top "$C_CYAN" "DEPLOYMENT STARTED"
draw_box_line "$C_CYAN" "Beginning automated installation of MikroTik CHR..."
draw_box_bottom "$C_CYAN"

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
    echo -e "\n${C_RED}Error: chr.qcow2 not found! Make sure you run inside installer directory.${C_RESET}"
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

# Generate a random MAC address
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
systemctl enable mikrotik-chr.service >/dev/null 2>&1

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

iptables -D FORWARD -i tap0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o tap0 -j ACCEPT 2>/dev/null || true
iptables -I FORWARD -i tap0 -j ACCEPT
iptables -I FORWARD -o tap0 -j ACCEPT

ip route add 10.100.0.0/24 via 100.64.0.2 2>/dev/null || true
netfilter-persistent save >/dev/null 2>&1

# Attention Box & Console Launch
echo ""
draw_box_top "$C_YELLOW" "IMPORTANT: INITIAL ROUTEROS CONFIGURATION"
draw_box_line "$C_YELLOW" "CHR starts with blank settings. Login as ${C_BOLD}admin${C_RESET} (empty password) and run:"
draw_box_line "$C_YELLOW" ""
draw_box_line "$C_YELLOW" "  ${C_CYAN}/ip address add address=100.64.0.2/24 interface=ether1${C_RESET}"
draw_box_line "$C_YELLOW" "  ${C_CYAN}/interface ethernet set ether1 arp=proxy-arp${C_RESET}"
draw_box_line "$C_YELLOW" "  ${C_CYAN}/ip route add dst-address=0.0.0.0/0 gateway=100.64.0.1${C_RESET}"
draw_box_line "$C_YELLOW" ""
draw_box_line "$C_YELLOW" "To exit console: Press ${C_BOLD}Ctrl + A${C_RESET}, release, then press ${C_BOLD}X${C_RESET}."
draw_box_line "$C_YELLOW" "Full setup & SSTP commands: ${C_CYAN}https://github.com/mhmd3010/chr${C_RESET}"
draw_box_bottom "$C_YELLOW"
echo ""

for i in 5 4 3 2 1; do
    printf "\r${C_BLINK}${C_RED}▶ Launching MikroTik console in %d second(s)... (Press Ctrl+C to cancel)\033[0m" "$i"
    sleep 1
done
printf "\r\033[K"

echo -e "${C_GREEN}Opening MikroTik Console...${C_RESET}\n"
eval $(grep ExecStart /etc/systemd/system/mikrotik-chr.service | cut -d '=' -f 2-) || true

echo -e "\n${C_CYAN}Starting MikroTik CHR background service...${C_RESET}"
systemctl start mikrotik-chr.service >/dev/null 2>&1 || true

echo ""
draw_box_top "$C_GREEN" "✔ INSTALLATION COMPLETE & SERVICE RUNNING"
draw_box_line "$C_GREEN" "Status:   ${C_GREEN}● Active (Running in background)${C_RESET}"
draw_box_line "$C_GREEN" "Winbox:   ${C_CYAN}port 7001${C_RESET} (forwarded to 100.64.0.2:8291)"
draw_box_line "$C_GREEN" "WebFig:   ${C_CYAN}port 7002${C_RESET} (forwarded to 100.64.0.2:80)"
draw_box_line "$C_GREEN" "SSTP VPN: ${C_CYAN}port 4443${C_RESET} (forwarded to 100.64.0.2:443)"
draw_box_bottom "$C_GREEN"
echo ""
