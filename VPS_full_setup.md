# 🛡️ Pi-Hole для Remnawave Node


## 🛡️ Шаг 6: Установить Pi-Hole
```bash
# Остановить systemd-resolved (занимает порт 53)
systemctl stop systemd-resolved
systemctl disable systemd-resolved

# Создать временный DNS
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# Проверить интернет
ping -c 2 google.com
# Должен ответить

# Установить Pi-Hole
curl -sSL https://install.pi-hole.net | bash
```


## 🔒 Шаг 7: Настроить DNS для Pi-Hole

```bash
# Настроить resolv.conf на Pi-Hole
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF

# Защитить от изменений
chattr +i /etc/resolv.conf

# Проверить DNS
dig @127.0.0.1 google.com +short
# Должен вернуть IP

# Проверить блокировку
dig @127.0.0.1 doubleclick.net +short
# Должен вернуть: 0.0.0.0
```




```bash
# 1. Освободить порт 53
systemctl stop systemd-resolved
systemctl disable systemd-resolved

# 2. Настроить временный DNS
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# 3. Установить Pi-Hole
curl -sSL https://install.pi-hole.net | bash
# Во время установки выбирайте "On (Recommended)" для всех опций
# ⚠️ ЗАПИШИТЕ ПАРОЛЬ в конце установки!

# 4. Настроить систему использовать Pi-Hole
cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF
chattr +i /etc/resolv.conf

# 5. Перезапустить Remnawave Node
cd /opt/remnanode
docker compose restart
```

## Проверка

```bash
# Проверить блокировку
dig @127.0.0.1 doubleclick.net +short
# Должен вернуть: 0.0.0.0

# Проверить статус
pihole status
```

## Дополнительно

```bash
# Добавить больше блок-листов (опционально)
apt install sqlite3 -y
sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'StevenBlack');"
pihole -g

# Web интерфейс: http://ваш_IP/admin
# Логин: admin
# Сменить пароль: pihole -a -p
```

## Команды

```bash
pihole status        # Статус
pihole -g            # Обновить блок-листы
pihole -t            # Мониторинг запросов
pihole disable 5m    # Отключить на 5 минут
pihole restartdns    # Перезапустить DNS
```

## Решение проблем

```bash
# Порт 53 занят
systemctl stop systemd-resolved
pihole restartdns

# DNS не работает
systemctl restart pihole-FTL

# resolv.conf изменился
chattr +i /etc/resolv.conf
```

---

## 📊 Полезные команды

### Docker:
```bash
docker ps                          # Список контейнеров
docker logs remnanode --tail 50   # Логи Node
docker compose restart             # Перезапустить Node
docker compose down                # Остановить Node
docker compose up -d               # Запустить Node
```

### Pi-Hole:
```bash
pihole status                      # Статус
pihole -g                          # Обновить блок-листы
pihole -t                          # Мониторинг запросов
pihole disable 5m                  # Отключить на 5 минут
pihole restartdns                  # Перезапустить DNS
```

### Системные:
```bash
htop                               # Мониторинг ресурсов
ss -tulpn | grep :443             # Проверить порт 443
ss -tulpn | grep :53              # Проверить порт 53
ufw status                        # Статус firewall
journalctl -u docker -f           # Логи Docker
```
