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

# Проверка и установка UFW
if ! command -v ufw &> /dev/null; then
    echo "🔧 UFW не установлен, устанавливаю..."
    apt-mark unhold ufw 2>/dev/null || true
    apt update -qq
    apt install -y --allow-change-held-packages ufw
    echo "✅ UFW установлен"
fi

# Проверка: уже настроено или нет
ALREADY_CONFIGURED=false
CONFIG_STATUS=""

echo "🔍 Проверка текущей конфигурации..."
echo ""

# Проверка компонентов
HAS_SYSCTL=false
HAS_IPTABLES=false
HAS_UFW_ACTIVE=false
HAS_BBR=false
HAS_TFO=false
HAS_BUFFERS=false
HAS_MTU_OPT=false

if [[ -f /etc/sysctl.d/99-xray-optimize.conf ]]; then
    HAS_SYSCTL=true
    CONFIG_STATUS+="✅ Файл конфигурации sysctl существует\n"
    
    # Проверка BBR
    if grep -q "tcp_congestion_control.*bbr" /etc/sysctl.d/99-xray-optimize.conf; then
        HAS_BBR=true
        CONFIG_STATUS+="✅ BBR настроен\n"
    else
        CONFIG_STATUS+="⚠️  BBR не настроен\n"
    fi
    
    # Проверка TCP Fast Open
    if grep -q "tcp_fastopen" /etc/sysctl.d/99-xray-optimize.conf; then
        HAS_TFO=true
        CONFIG_STATUS+="✅ TCP Fast Open настроен\n"
    else
        CONFIG_STATUS+="⚠️  TCP Fast Open не настроен\n"
    fi
    
    # Проверка TCP буферов
    if grep -q "rmem_max.*134217728" /etc/sysctl.d/99-xray-optimize.conf; then
        HAS_BUFFERS=true
        CONFIG_STATUS+="✅ TCP буферы увеличены\n"
    else
        CONFIG_STATUS+="⚠️  TCP буферы не оптимизированы\n"
    fi
else
    CONFIG_STATUS+="⚠️  Файл конфигурации sysctl отсутствует\n"
fi

if [[ -f /etc/iptables/rules.v4 ]]; then
    HAS_IPTABLES=true
    CONFIG_STATUS+="✅ Правила iptables существуют\n"
else
    CONFIG_STATUS+="⚠️  Правила iptables отсутствуют\n"
fi

if ufw status | grep -q "Status: active"; then
    HAS_UFW_ACTIVE=true
    CONFIG_STATUS+="✅ UFW активен\n"
else
    CONFIG_STATUS+="⚠️  UFW не активен\n"
fi

# Проверка MTU оптимизации
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5}' | head -n1)
if [[ -n "$IFACE" ]]; then
    CURRENT_MTU=$(ip link show $IFACE | grep -oP 'mtu \K\d+')
    if [[ "$CURRENT_MTU" -lt 1500 ]]; then
        HAS_MTU_OPT=true
        CONFIG_STATUS+="✅ MTU оптимизирован ($IFACE: $CURRENT_MTU)\n"
    else
        CONFIG_STATUS+="ℹ️  MTU стандартный ($IFACE: $CURRENT_MTU)\n"
    fi
fi

echo -e "$CONFIG_STATUS"
echo ""

# Определяем нужна ли полная установка
if [[ "$HAS_SYSCTL" == "true" ]] && [[ "$HAS_IPTABLES" == "true" ]] && [[ "$HAS_UFW_ACTIVE" == "true" ]]; then
    ALREADY_CONFIGURED=true
    echo "📋 Базовая конфигурация обнаружена"
    echo ""
    
    # Спрашиваем что добавить
    INSTALL_COMPONENTS=false
    
    if [[ "$HAS_TFO" == "false" ]] || [[ "$HAS_BUFFERS" == "false" ]] || [[ "$HAS_BBR" == "false" ]] || [[ "$HAS_MTU_OPT" == "false" ]]; then
        echo "🔧 Доступны дополнительные оптимизации:"
        [[ "$HAS_BBR" == "false" ]] && echo "   - TCP BBR"
        [[ "$HAS_TFO" == "false" ]] && echo "   - TCP Fast Open"
        [[ "$HAS_BUFFERS" == "false" ]] && echo "   - Увеличенные TCP буферы"
        [[ "$HAS_MTU_OPT" == "false" ]] && echo "   - MTU оптимизация"
        echo ""
        
        # Устанавливаем флаг для добавления компонентов
        INSTALL_COMPONENTS=true
        ACTIONS_DONE=""
    else
        echo "✅ Все компоненты уже установлены"
        echo "Переход к проверке..."
        echo ""
    fi
else
    echo "🚀 Начинаю полную установку..."
    echo ""
fi

if [[ "$ALREADY_CONFIGURED" == "false" ]] || [[ "$INSTALL_COMPONENTS" == "true" ]]; then
    
    # Список выполненных действий
    if [[ -z "$ACTIONS_DONE" ]]; then
        ACTIONS_DONE=""
    fi
    
    if [[ "$ALREADY_CONFIGURED" == "false" ]]; then
        # 1. Сброс UFW
        echo "[1/9] Сброс UFW..."
        apt-mark hold ufw 2>/dev/null || true
        ufw --force reset
        ACTIONS_DONE+="✅ UFW сброшен и настроен\n"
    else
        echo "[ПРОПУСК] UFW уже настроен"
    fi
else
    echo "[ПРОПУСК] UFW уже настроен"
fi

if [[ "$ALREADY_CONFIGURED" == "false" ]]; then
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
    echo "[9/9] Настройка системных параметров..."
    
    # Базовый конфиг (всегда создаём при первой установке)
    if [[ "$ALREADY_CONFIGURED" == "false" ]]; then
        cat > /etc/sysctl.d/99-xray-optimize.conf << 'EOF'
# TCP оптимизации для VPN
net.ipv4.tcp_syncookies = 0

# Отключение IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Ускорение установки TCP соединений
net.ipv4.tcp_fastopen = 3

# TCP буферы для высокой пропускной способности
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF
        # Применяем настройки немедленно
        sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null 2>&1
        sysctl -w net.core.rmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.core.wmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864" > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864" > /dev/null 2>&1
        sysctl -w net.core.netdev_max_backlog=5000 > /dev/null 2>&1
        
        ACTIONS_DONE+="✅ Базовые параметры sysctl настроены\n"
        ACTIONS_DONE+="✅ TCP Fast Open установлен\n"
        ACTIONS_DONE+="✅ TCP буферы увеличены до 128 МБ\n"
    fi
    
    # Спрашиваем про BBR (если не установлен)
    if [[ "$HAS_BBR" == "false" ]]; then
        echo ""
        echo "⚙️  Установить TCP BBR (рекомендуется для VPN)?"
        echo "   Если планируешь ставить BBR3 отдельно - выбери N"
        read -p "   Установить стандартный BBR? (Y/n): " -n 1 -r BBR_CHOICE
        echo ""
        
        if [[ $BBR_CHOICE =~ ^[Nn]$ ]]; then
            echo "ℹ️  Пропуск установки BBR (установи BBR3 отдельно)"
            ACTIONS_DONE+="⚠️  BBR не установлен (установи BBR3 отдельно)\n"
        else
            echo "✅ Установка стандартного BBR"
            cat >> /etc/sysctl.d/99-xray-optimize.conf << 'EOF'

# TCP BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
            ACTIONS_DONE+="✅ TCP BBR установлен\n"
        fi
    fi
    
    # TCP Fast Open (добавляем только если повторный запуск)
    if [[ "$ALREADY_CONFIGURED" == "true" ]] && [[ "$HAS_TFO" == "false" ]]; then
        echo "[+] Установка TCP Fast Open (ускорение соединений для XHTTP)..."
        cat >> /etc/sysctl.d/99-xray-optimize.conf << 'EOF'

# Ускорение установки TCP соединений
net.ipv4.tcp_fastopen = 3
EOF
        sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null 2>&1
        ACTIONS_DONE+="✅ TCP Fast Open установлен\n"
    elif [[ "$ALREADY_CONFIGURED" == "true" ]] && [[ "$HAS_TFO" == "true" ]]; then
        echo "[✓] TCP Fast Open уже установлен"
        ACTIONS_DONE+="✅ TCP Fast Open уже был установлен\n"
    fi
    
    # TCP буферы (добавляем только если повторный запуск)
    if [[ "$ALREADY_CONFIGURED" == "true" ]] && [[ "$HAS_BUFFERS" == "false" ]]; then
        echo "[+] Увеличение TCP буферов для каналов >100 Мбит/с..."
        cat >> /etc/sysctl.d/99-xray-optimize.conf << 'EOF'

# TCP буферы для высокой пропускной способности
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF
        sysctl -w net.core.rmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.core.wmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864" > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864" > /dev/null 2>&1
        sysctl -w net.core.netdev_max_backlog=5000 > /dev/null 2>&1
        ACTIONS_DONE+="✅ TCP буферы увеличены до 128 МБ\n"
    elif [[ "$ALREADY_CONFIGURED" == "true" ]] && [[ "$HAS_BUFFERS" == "true" ]]; then
        echo "[✓] TCP буферы уже увеличены"
        ACTIONS_DONE+="✅ TCP буферы уже были увеличены\n"
    fi

    # Самопроверка/добавление: если после логики выше в конфиге всё ещё нет TFO или буферов, добавляем без вопросов
    if ! grep -q "net.ipv4.tcp_fastopen" /etc/sysctl.d/99-xray-optimize.conf; then
        echo "[+] Авто-добавление TCP Fast Open (самопроверка)"
        cat >> /etc/sysctl.d/99-xray-optimize.conf << 'EOF'

# Ускорение установки TCP соединений
net.ipv4.tcp_fastopen = 3
EOF
        sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null 2>&1
        ACTIONS_DONE+="✅ TCP Fast Open добавлен (самопроверка)\n"
    fi

    if ! grep -q "net.core.rmem_max = 134217728" /etc/sysctl.d/99-xray-optimize.conf; then
        echo "[+] Авто-добавление TCP буферов (самопроверка)"
        cat >> /etc/sysctl.d/99-xray-optimize.conf << 'EOF'

# TCP буферы для высокой пропускной способности
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF
        sysctl -w net.core.rmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.core.wmem_max=134217728 > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864" > /dev/null 2>&1
        sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864" > /dev/null 2>&1
        sysctl -w net.core.netdev_max_backlog=5000 > /dev/null 2>&1
        ACTIONS_DONE+="✅ TCP буферы добавлены (самопроверка)\n"
    fi
    
    # MTU оптимизация (если не установлена)
    if [[ "$HAS_MTU_OPT" == "false" ]]; then
        echo ""
        echo "⚙️  Настроить MTU оптимизацию?"
        echo "   Рекомендуется если провайдер использует PPPoE или VPN"
        IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5}' | head -n1)
        CURRENT_MTU=$(ip link show $IFACE 2>/dev/null | grep -oP 'mtu \K\d+')
        echo "   Текущий интерфейс: $IFACE (MTU: $CURRENT_MTU)"
        
        # Тест оптимального MTU
        echo ""
        echo "   🔍 Тестирование оптимального MTU..."
        if ping -c 1 -M do -s 1472 8.8.8.8 &>/dev/null; then
            echo "   ✅ MTU 1500 работает отлично"
            MTU_RECOMMENDED=1500
        elif ping -c 1 -M do -s 1452 8.8.8.8 &>/dev/null; then
            echo "   ⚠️  Рекомендуется MTU 1480 (PPPoE обнаружен)"
            MTU_RECOMMENDED=1480
        elif ping -c 1 -M do -s 1392 8.8.8.8 &>/dev/null; then
            echo "   ⚠️  Рекомендуется MTU 1420 (VPN/туннель обнаружен)"
            MTU_RECOMMENDED=1420
        else
            echo "   ⚠️  Рекомендуется MTU 1420"
            MTU_RECOMMENDED=1420
        fi
        
        if [[ "$CURRENT_MTU" -eq 1500 ]] && [[ "$MTU_RECOMMENDED" -lt 1500 ]]; then
            read -p "   Установить MTU $MTU_RECOMMENDED? (Y/n): " -n 1 -r MTU_CHOICE
        else
            read -p "   Установить MTU 1420? (Y/n): " -n 1 -r MTU_CHOICE
            MTU_RECOMMENDED=1420
        fi
        echo ""
        
        if [[ ! $MTU_CHOICE =~ ^[Nn]$ ]]; then
            if [[ -n "$IFACE" ]]; then
                echo "✅ Установка MTU $MTU_RECOMMENDED на $IFACE"
                ip link set dev $IFACE mtu $MTU_RECOMMENDED
                
                # Делаем постоянным через netplan или systemd-networkd
                if [[ -d /etc/netplan ]]; then
                    # Netplan (Ubuntu 18.04+)
                    cat > /etc/netplan/99-mtu.yaml << EOF
network:
  version: 2
  ethernets:
    $IFACE:
      mtu: $MTU_RECOMMENDED
EOF
                    netplan apply 2>/dev/null || true
                    ACTIONS_DONE+="✅ MTU $MTU_RECOMMENDED установлен на $IFACE (netplan)\n"
                elif [[ -d /etc/systemd/network ]]; then
                    # systemd-networkd
                    cat > /etc/systemd/network/10-$IFACE.network << EOF
[Match]
Name=$IFACE

[Link]
MTUBytes=$MTU_RECOMMENDED
EOF
                    systemctl restart systemd-networkd 2>/dev/null || true
                    ACTIONS_DONE+="✅ MTU $MTU_RECOMMENDED установлен на $IFACE (systemd-networkd)\n"
                else
                    ACTIONS_DONE+="⚠️  MTU установлен временно (до перезагрузки)\n"
                fi
            else
                echo "❌ Не удалось определить сетевой интерфейс"
            fi
        else
            echo "ℹ️  Пропуск MTU оптимизации"
        fi
    fi

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
    netfilter-persistent save
    
    ACTIONS_DONE+="✅ iptables правила настроены и сохранены\n"
    
    echo ""
    echo "✅ Настройка завершена!"
    
    # Вывод итогов (только если есть действия)
    if [[ -n "$ACTIONS_DONE" ]]; then
        echo ""
        echo "================================"
        echo "ВЫПОЛНЕННЫЕ ДЕЙСТВИЯ"
        echo "================================"
        echo -e "$ACTIONS_DONE"
        echo "================================"
    fi
    echo "[ПРОПУСК] Все компоненты уже установлены"
    
    # Проверяем и исправляем только iptables если есть дубли
    IFACE=$(ip route get 1.1.1.1 | awk '{print $5}' | head -n1)
    PREROUTING_COUNT=$(iptables -t mangle -L PREROUTING -n | grep -c "TTL" || echo "0")
    POSTROUTING_COUNT=$(iptables -t mangle -L POSTROUTING -n | grep -c "TTL" || echo "0")
    
    if [[ $PREROUTING_COUNT -gt 1 ]] || [[ $POSTROUTING_COUNT -gt 2 ]]; then
        echo "⚠️ Обнаружены дубли iptables, исправляю..."
        # Очистка дублей
        iptables -t mangle -F PREROUTING 2>/dev/null || true
        iptables -t mangle -F POSTROUTING 2>/dev/null || true
        
        # Добавление правил
        iptables -t mangle -A PREROUTING -p tcp --dport 443 -j TTL --ttl-set 64
        iptables -t mangle -A POSTROUTING -o $IFACE -j TTL --ttl-set 64
        iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        
        iptables-save > /etc/iptables/rules.v4
        netfilter-persistent save
        echo "✅ Дубли удалены, правила восстановлены"
    fi
fi

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

# 3. Проверка TCP BBR/Congestion Control
echo "📋 3. TCP CONGESTION CONTROL:"
echo "----------------------------"
CC_STATUS=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo "unknown")
echo "Текущий: $CC_STATUS"
if [[ "$CC_STATUS" == "bbr" ]]; then
    echo "✅ Стандартный BBR активен"
    lsmod | grep tcp_bbr && echo "✅ Модуль tcp_bbr загружен" || echo "⚠️ Модуль tcp_bbr не загружен"
elif [[ "$CC_STATUS" == "bbr3" ]]; then
    echo "✅ BBR3 активен"
else
    echo "ℹ️  Используется: $CC_STATUS"
fi
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

# 7. Проверка интерфейса и MTU
echo "📋 7. СЕТЕВОЙ ИНТЕРФЕЙС И MTU:"
echo "----------------------------"
IFACE=$(ip route get 1.1.1.1 | awk '{print $5}' | head -n1)
echo "Используемый интерфейс: $IFACE"
ip addr show $IFACE | grep -E "inet |mtu"

# Проверка оптимального MTU
echo ""
echo "🔍 Проверка оптимального MTU:"
CURRENT_MTU=$(ip link show $IFACE 2>/dev/null | grep -oP 'mtu \K\d+')
echo "   Текущий MTU: $CURRENT_MTU"

# Тест MTU с ping (без фрагментации)
echo "   Тестирование MTU до 8.8.8.8..."
if ping -c 1 -M do -s 1472 8.8.8.8 &>/dev/null; then
    echo "   ✅ MTU 1500 работает (пакеты 1472+28 байт проходят)"
    MTU_RECOMMENDED=1500
elif ping -c 1 -M do -s 1452 8.8.8.8 &>/dev/null; then
    echo "   ⚠️  MTU 1500 не проходит, но 1480 работает"
    echo "   💡 Рекомендуется: MTU 1480 (PPPoE обнаружен)"
    MTU_RECOMMENDED=1480
elif ping -c 1 -M do -s 1392 8.8.8.8 &>/dev/null; then
    echo "   ⚠️  MTU 1480 не проходит, но 1420 работает"
    echo "   💡 Рекомендуется: MTU 1420 (VPN/туннель обнаружен)"
    MTU_RECOMMENDED=1420
else
    echo "   ❌ Проблемы с MTU, рекомендуется 1420"
    MTU_RECOMMENDED=1420
fi

if [[ "$CURRENT_MTU" -ne "$MTU_RECOMMENDED" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 КОМАНДЫ ДЛЯ РУЧНОЙ УСТАНОВКИ MTU"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1️⃣  Установить MTU $MTU_RECOMMENDED временно (до перезагрузки):"
    echo "    sudo ip link set dev $IFACE mtu $MTU_RECOMMENDED"
    echo ""
    echo "2️⃣  Проверить применение:"
    echo "    ip link show $IFACE | grep mtu"
    echo ""
    echo "3️⃣  Сделать постоянным (выбери свой метод):"
    echo ""
    echo "    ┌─ Вариант A: Netplan (Ubuntu 18.04+, Debian 11+)"
    echo "    │"
    echo "    │  sudo bash -c 'cat > /etc/netplan/99-mtu.yaml <<EOF"
    echo "    │  network:"
    echo "    │    version: 2"
    echo "    │    ethernets:"
    echo "    │      $IFACE:"
    echo "    │        mtu: $MTU_RECOMMENDED"
    echo "    │  EOF'"
    echo "    │"
    echo "    │  sudo netplan apply"
    echo "    └─"
    echo ""
    echo "    ┌─ Вариант B: systemd-networkd (Debian, CentOS, RHEL)"
    echo "    │"
    echo "    │  sudo bash -c 'cat > /etc/systemd/network/10-$IFACE.network <<EOF"
    echo "    │  [Match]"
    echo "    │  Name=$IFACE"
    echo "    │  "
    echo "    │  [Link]"
    echo "    │  MTUBytes=$MTU_RECOMMENDED"
    echo "    │  EOF'"
    echo "    │"
    echo "    │  sudo systemctl restart systemd-networkd"
    echo "    └─"
    echo ""
    echo "    ┌─ Вариант C: /etc/network/interfaces (старый Debian/Ubuntu)"
    echo "    │"
    echo "    │  sudo bash -c 'echo \"post-up ip link set dev $IFACE mtu $MTU_RECOMMENDED\" >> /etc/network/interfaces'"
    echo "    │  sudo systemctl restart networking"
    echo "    └─"
    echo ""
    echo "4️⃣  Проверка после установки:"
    echo "    ip link show $IFACE | grep mtu"
    echo "    ping -c 3 -M do -s $((MTU_RECOMMENDED - 28)) 8.8.8.8"
    echo ""
    echo "5️⃣  Откат если что-то пошло не так:"
    echo "    sudo ip link set dev $IFACE mtu 1500"
    echo "    sudo rm /etc/netplan/99-mtu.yaml && sudo netplan apply"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "   ✅ MTU оптимален ($CURRENT_MTU), настройка не требуется"
fi
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
