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
echo "ПРОВЕРКА КОНФИГУРАЦИИ"
echo "================================"
echo ""

# 1. Проверка UFW
echo "📋 1. UFW СТАТУС И ПРАВИЛА:"
echo "----------------------------"
ufw status numbered
echo ""

# 2. Проверка открытых портов
echo "📋 2. ОТКРЫТЫЕ ПОРТЫ (ss):"
echo "----------------------------"
ss -tulnp | grep -E ':(22|443|8443|8444|9443|9999|8388|8389|1234)\s' || echo "⚠️ Порты XRay еще не слушаются (запусти XRay)"
echo ""

# 3. Проверка TCP BBR
echo "📋 3. TCP BBR СТАТУС:"
echo "----------------------------"
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
if [[ "$BBR_STATUS" == "bbr" ]]; then
    echo "✅ TCP BBR включен: $BBR_STATUS"
else
    echo "❌ TCP BBR НЕ включен: $BBR_STATUS"
fi
lsmod | grep tcp_bbr && echo "✅ Модуль tcp_bbr загружен" || echo "❌ Модуль tcp_bbr НЕ загружен"
echo ""

# 4. Проверка IPv6
echo "📋 4. IPv6 СТАТУС:"
echo "----------------------------"
IPV6_STATUS=$(sysctl net.ipv6.conf.all.disable_ipv6 | awk '{print $3}')
if [[ "$IPV6_STATUS" == "1" ]]; then
    echo "✅ IPv6 отключен"
else
    echo "⚠️ IPv6 включен (может быть конфликт)"
fi
echo ""

# 5. Проверка iptables правил
echo "📋 5. IPTABLES MANGLE ПРАВИЛА:"
echo "----------------------------"
MANGLE_COUNT=$(iptables -t mangle -L -n | grep -c "TTL" || echo "0")
echo "Найдено TTL правил: $MANGLE_COUNT"
iptables -t mangle -L -n -v --line-numbers | grep -E "TTL|TCPMSS|Chain"
echo ""

# 6. Проверка на дубли в iptables
echo "📋 6. ПРОВЕРКА ДУБЛЕЙ IPTABLES:"
echo "----------------------------"
PREROUTING_DUPES=$(iptables -t mangle -L PREROUTING -n | grep -c "TTL" || echo "0")
POSTROUTING_DUPES=$(iptables -t mangle -L POSTROUTING -n | grep -c "TTL" || echo "0")
if [[ $PREROUTING_DUPES -gt 1 ]]; then
    echo "⚠️ ОБНАРУЖЕНЫ ДУБЛИ в PREROUTING ($PREROUTING_DUPES правил TTL)"
else
    echo "✅ PREROUTING: дублей нет ($PREROUTING_DUPES правило)"
fi
if [[ $POSTROUTING_DUPES -gt 2 ]]; then
    echo "⚠️ ОБНАРУЖЕНЫ ДУБЛИ в POSTROUTING ($POSTROUTING_DUPES правил TTL)"
else
    echo "✅ POSTROUTING: дублей нет ($POSTROUTING_DUPES правила)"
fi
echo ""

# 7. Проверка интерфейса
echo "📋 7. СЕТЕВОЙ ИНТЕРФЕЙС:"
echo "----------------------------"
IFACE=$(ip route get 1.1.1.1 | awk '{print $5}' | head -n1)
echo "Используемый интерфейс: $IFACE"
ip addr show $IFACE | grep -E "inet |mtu"
echo ""

# 8. Проверка конфликтов портов
echo "📋 8. КОНФЛИКТЫ ПОРТОВ:"
echo "----------------------------"
for PORT in 22 443 8443 8444 9443 9999 8388 8389 1234; do
    if ss -tuln | grep -q ":$PORT "; then
        PROCESS=$(ss -tulnp | grep ":$PORT " | awk '{print $7}' | head -n1)
        echo "✅ Порт $PORT занят: $PROCESS"
    else
        echo "⚠️ Порт $PORT свободен (XRay не запущен?)"
    fi
done
echo ""

# 9. Проверка автозагрузки iptables
echo "📋 9. АВТОЗАГРУЗКА IPTABLES:"
echo "----------------------------"
if systemctl is-enabled netfilter-persistent &>/dev/null; then
    echo "✅ netfilter-persistent включен (правила загружаются при старте)"
else
    echo "⚠️ netfilter-persistent не включен"
fi
if [[ -f /etc/iptables/rules.v4 ]]; then
    echo "✅ Файл /etc/iptables/rules.v4 существует"
    echo "   Размер: $(wc -l < /etc/iptables/rules.v4) строк"
else
    echo "❌ Файл /etc/iptables/rules.v4 НЕ найден"
fi
echo ""

# Финальная оценка
echo "================================"
echo "ИТОГОВАЯ ОЦЕНКА"
echo "================================"

ERRORS=0
WARNINGS=0

[[ "$BBR_STATUS" != "bbr" ]] && ((ERRORS++))
[[ $PREROUTING_DUPES -gt 1 ]] && ((WARNINGS++))
[[ $POSTROUTING_DUPES -gt 2 ]] && ((WARNINGS++))
[[ ! -f /etc/iptables/rules.v4 ]] && ((ERRORS++))

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo "✅ ВСЁ ОТЛИЧНО! Конфликтов не обнаружено."
elif [[ $ERRORS -eq 0 ]]; then
    echo "⚠️ Есть предупреждения ($WARNINGS), но критичных ошибок нет."
else
    echo "❌ Обнаружено ошибок: $ERRORS, предупреждений: $WARNINGS"
fi

echo ""
echo "💡 Запусти XRay для проверки портов: systemctl status xray"
echo "💡 Проверь логи UFW: tail -f /var/log/ufw.log"
echo "================================"
