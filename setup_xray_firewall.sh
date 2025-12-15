#!/bin/bash

# XRay VPN Server Security Setup Script
# Автоматическая настройка UFW, iptables и системных параметров

set -e  # Остановка при ошибке

echo "================================"
echo "XRay VPN Server Setup"
echo "================================"

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
   echo "Запусти скрипт с sudo или под root"
   exit 1
fi

# 1. Сброс UFW
echo "[1/9] Сброс UFW..."
apt-mark hold ufw 2>/dev/null || true
ufw --force reset

# 2. Политики по умолчанию
echo "[2/9] Настройка политик UFW..."
ufw default deny incoming
ufw default allow outgoing

# 3. SSH
echo "[3/9] Разрешение SSH..."
ufw allow 22/tcp comment 'SSH'

# 4. XRay порты
echo "[4/9] Разрешение XRay портов..."
ufw allow 443/tcp comment 'XRay Reality'
ufw allow 8443/tcp comment 'XRay Reality 2'
ufw allow 8444/tcp comment 'XRay Reality 3'
ufw allow 9443/tcp comment 'XRay Reality 4'
ufw allow 9999/tcp comment 'XRay Reality 5'

# 5. Shadowsocks порты
echo "[5/9] Разрешение Shadowsocks..."
ufw allow 8388/tcp comment 'Shadowsocks ChaCha20'
ufw allow 8388/udp comment 'Shadowsocks ChaCha20 UDP'
ufw allow 8389/tcp comment 'Shadowsocks XChaCha20'
ufw allow 8389/udp comment 'Shadowsocks XChaCha20 UDP'
ufw allow 1234/tcp comment 'Shadowsocks Basic'
ufw allow 1234/udp comment 'Shadowsocks Basic UDP'

# 6. API управления (раскомментируй если используешь Remnawave)
# ufw allow from 212.113.109.68 to any port 2222 proto tcp comment 'Remnawave Panel API'

# 7. Блокировки
echo "[6/9] Блокировка LLMNR..."
ufw deny 5355 comment 'Block LLMNR'

# 8. Отключение IPv6 в UFW
echo "[7/9] Отключение IPv6..."
sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw

# 9. Включение UFW
echo "[8/9] Включение UFW..."
ufw --force enable

# 10. Системные оптимизации
echo "[9/9] Настройка TCP BBR и оптимизаций..."
cat > /etc/sysctl.d/99-xray-optimize.conf << 'EOF'
# TCP оптимизации для VPN
net.ipv4.tcp_syncookies = 0
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Отключение IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl -p /etc/sysctl.d/99-xray-optimize.conf

# 11. Настройка iptables (TTL маскировка)
echo "Настройка iptables для маскировки TTL..."
mkdir -p /etc/iptables

# Определяем сетевой интерфейс
IFACE=$(ip route get 1.1.1.1 | awk '{print $5}' | head -n1)
echo "Интерфейс: $IFACE"

# Очистка старых правил TTL (чтобы не было дублей)
iptables -t mangle -D PREROUTING -p tcp --dport 443 -j TTL --ttl-set 64 2>/dev/null || true
iptables -t mangle -D POSTROUTING -o $IFACE -j TTL --ttl-set 64 2>/dev/null || true
iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true

# Добавление правил
iptables -t mangle -A PREROUTING -p tcp --dport 443 -j TTL --ttl-set 64
iptables -t mangle -A POSTROUTING -o $IFACE -j TTL --ttl-set 64
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Сохранение правил
iptables-save > /etc/iptables/rules.v4

# Установка iptables-persistent (автозагрузка правил)
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt update -qq
apt install -y iptables-persistent

netfilter-persistent save

# Финальная проверка
echo ""
echo "================================"
echo "Установка завершена!"
echo "================================"
echo ""
echo "UFW статус:"
ufw status numbered
echo ""
echo "Открытые порты:"
ss -tulnp | grep -E ':(22|443|8443|8444|9443|9999|8388|8389|1234)\s'
echo ""
echo "TCP BBR статус:"
sysctl net.ipv4.tcp_congestion_control
lsmod | grep tcp_bbr
echo ""
echo "iptables правила (mangle table):"
iptables -t mangle -L -n -v --line-numbers
echo ""
echo "✅ Конфигурация завершена успешно!"
