#!/bin/bash
# phoenixwings.sh
# Phoenix Wings VPS Optimizer

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Simple ASCII Banner (Red)
ASCII_ART="${RED}
===============================
     Phoenix Wings Optimizer
===============================
${NC}"

# Check root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root${NC}"
        exit 1
    fi
}

# Initialize
initialize() {
    check_root
    if ! command -v figlet &> /dev/null; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y figlet >/dev/null 2>&1 || true
    fi
    clear
    echo -e "$ASCII_ART"
    echo -e "${YELLOW}Phoenix Wings Community:${NC} https://discord.gg/phoenixwings"
    echo -e "\n${RED}SECURITY NOTICE: This script will make significant system changes!${NC}\n"
}

# Section header
section_header() {
    clear
    echo -e "${CYAN}"
    if command -v figlet &> /dev/null; then
        figlet -c "$1"
    else
        echo "===== $1 ====="
    fi
    echo -e "${NC}"
    echo "======================================================"
}

# Progress bar
progress_bar() {
    local duration=${1:-2}
    local steps=20
    local step_delay
    step_delay=$(awk "BEGIN {print $duration/$steps}")
    echo -ne "${BLUE}["
    for ((i=0;i<steps;i++)); do
        echo -ne "="
        sleep "$step_delay"
    done
    echo -e "]${NC}"
}

# === Full System Optimization ===
full_optimization() {
    section_header "Full Optimization"

    echo -e "${YELLOW}[1/8] Deep Cleaning System...${NC}"
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    rm -rf /var/cache/apt/archives/* /var/cache/apt/*.bin 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    journalctl --vacuum-size=200M --quiet 2>/dev/null || true
    find /var/log -type f -regex '.*\.\(gz\|[0-9]\)$' -delete 2>/dev/null || true
    apt-get clean -y >/dev/null 2>&1 || true
    apt-get autoclean -y >/dev/null 2>&1 || true
    apt-get autoremove --purge -y >/dev/null 2>&1 || true
    progress_bar 2

    echo -e "${YELLOW}[2/8] Swap Configuration...${NC}"
    swapoff -a 2>/dev/null || true
    rm -f /swapfile 2>/dev/null || true
    dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none 2>/dev/null || true
    chmod 600 /swapfile 2>/dev/null || true
    mkswap /swapfile >/dev/null 2>&1 || true
    swapon /swapfile 2>/dev/null || true
    grep -q '/swapfile' /etc/fstab 2>/dev/null || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    progress_bar 1

    echo -e "${YELLOW}[3/8] Kernel Optimization...${NC}"
    cat >> /etc/sysctl.conf <<'EOL'
# Network Optimization
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.core.somaxconn=65535
net.core.netdev_max_backlog=16384
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# DDoS Protection
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_syn_retries=3
EOL
    sysctl -p >/dev/null 2>&1 || true
    progress_bar 1

    echo -e "${YELLOW}[4/8] Security Hardening...${NC}"
    chmod 700 /root 2>/dev/null || true
    [ -f /etc/ssh/sshd_config ] && chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config 2>/dev/null || true
    echo "kernel.kptr_restrict=2" >> /etc/sysctl.conf
    echo "kernel.dmesg_restrict=1" >> /etc/sysctl.conf
    progress_bar 1

    echo -e "${YELLOW}[5/8] Installing Tools...${NC}"
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y zram-tools tuned sysstat iotop fail2ban >/dev/null 2>&1 || true
    systemctl enable tuned >/dev/null 2>&1 || true
    systemctl start tuned >/dev/null 2>&1 || true
    tuned-adm profile latency-performance >/dev/null 2>&1 || true
    progress_bar 2

    echo -e "${YELLOW}[6/8] Filesystem Tuning...${NC}"
    if lsblk -d -o rota | grep -q '0' 2>/dev/null; then
        sed -i '/noatime/d' /etc/fstab 2>/dev/null || true
        sed -i '/relatime/d' /etc/fstab 2>/dev/null || true
        echo "/ / ext4 defaults,noatime,relatime,discard 0 0" >> /etc/fstab
        fstrim -av >/dev/null 2>&1 || true
    else
        echo "noatime,relatime" >> /etc/fstab
    fi
    mount -o remount / >/dev/null 2>&1 || true
    progress_bar 1

    echo -e "${YELLOW}[7/8] CPU Optimization...${NC}"
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            echo performance > "$governor" 2>/dev/null || true
        done
    fi
    echo 'GOVERNOR="performance"' | tee /etc/default/cpufrequtils >/dev/null 2>&1 || true
    progress_bar 1

    echo -e "${YELLOW}[8/8] Scheduling Maintenance...${NC}"
    (crontab -l 2>/dev/null; echo "@daily /usr/bin/env bash /root/.phoenixwings_cleaner.sh --silent") | crontab - 2>/dev/null || true
    cat > /root/.phoenixwings_cleaner.sh <<'EOL'
#!/bin/bash
echo "$(date) - Phoenix Wings AutoClean Running..."
rm -rf /tmp/* /var/tmp/*
apt-get autoremove --purge -y >/dev/null 2>&1 || true
journalctl --vacuum-time=1d --quiet >/dev/null 2>&1 || true
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
fstrim -av >/dev/null 2>&1 || true
EOL
    chmod 700 /root/.phoenixwings_cleaner.sh 2>/dev/null || true
    progress_bar 1

    echo -e "\n${GREEN}Optimization Complete!${NC}"
    echo -e "${YELLOW}Recommended Actions:${NC}"
    echo "1. Reboot server"
    echo "2. Check: sysctl -a | grep 'swappiness\\|vfs_cache_pressure'"
    echo "3. Monitor with: htop && iotop"
    echo -e "${NC}"
    sleep 2
    main_menu
}

# === Main Menu ===
main_menu() {
    section_header "Phoenix Wings VPS Optimizer"

    PS3=$'\n'"Select Operation: "
    options=("Full System Optimization" 
             "Advanced DDoS Protection" 
             "Pterodactyl Management" 
             "Emergency Repair" 
             "Exit")

    select opt in "${options[@]}"; do
        case $opt in
            "Full System Optimization") full_optimization ;;
            "Advanced DDoS Protection") ddos_protection_menu ;;
            "Pterodactyl Management") pterodactyl_setup ;;
            "Emergency Repair") emergency_repair ;;
            "Exit") exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
    done
}

# Start Script
initialize
main_menu
