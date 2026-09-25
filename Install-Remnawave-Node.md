# Ручная установка Remnawave Node

Пошаговое руководство по ручной установке и базовой настройке ноды **Remnawave** на чистый сервер Linux, включая сетевую оптимизацию и опциональное развертывание компонента маскировки **SelfSteel** на базе веб-сервера Caddy.

---

## 1. Системная подготовка и оптимизация

Перед установкой обновите системные пакеты:
```bash
apt update && apt upgrade -y
```

### 🚀 Настройка сетевого ускорения (BBR)
Активируйте стандартный алгоритм контроля заторов BBR для минимизации потерь пакетов:
```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf && echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf && sysctl -p
```

### ⚙️ Дополнительные системные настройки (По желанию)

* **Установка актуальной версии BBR3**
  Если ваше ядро поддерживает BBR3, можно запустить автоматический скрипт оптимизации:
  ```bash
  bash <(curl -sSL https://raw.githubusercontent.com/ivan-nginx/bbr3/main/optimize_network.sh)
  ```

* **Полное отключение IPv6**
  Если на сервере не используется IPv6-трафик, его рекомендуется отключить для избежания конфликтов маршрутизации:
  ```bash
  curl -fsSL LinuxTools.World/IPv6_Toggle.sh | bash
  ```

---

## 2. Установка Docker

Установите актуальную версию Docker-движка с официального репозитория:
```bash
sudo curl -fsSL https://get.docker.com | sh
```

---

## 3. Развертывание Remnawave Node

1. Создайте рабочую директорию для ноды и перейдите в неё:
   ```bash
   mkdir -p /opt/remnanode && cd /opt/remnanode
   ```

2. Создайте и отредактируйте конфигурационный файл Docker Compose:
   ```bash
   nano docker-compose.yml
   ```
   *(Вставьте сюда конфигурацию вашей ноды Remnawave, сохраните файл через `Ctrl+O` -> `Enter`, закройте через `Ctrl+X`)*

3. Запустите контейнер ноды в фоновом режиме:
   ```bash
   docker compose up -d
   ```

---

## 4. Настройка SelfSteel (Опционально)

Компонент **SelfSteel** используется для гибкого проксирования, TLS-маскировки туннелей и отдачи фейкового сайта (заглушки) для защиты от активного сканирования.

### Шаг 4.1. Создание структуры папок и Caddyfile
```bash
mkdir -p /opt/selfsteel && cd /opt/selfsteel && nano Caddyfile
```

Вставьте следующую конфигурацию в `Caddyfile`:

```caddy
{
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server

}


:{$SELF_STEAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
```

### Шаг 4.2. Конфигурация окружения
Создайте файл переменных окружения `.env`:
```bash
nano .env
```
Заполните вашими данными (укажите ваш домен, порт по умолчанию оставьте `9443` или измените):
```env
SELF_STEAL_DOMAIN=your-domain.com
SELF_STEAL_PORT=9443
```

### Шаг 4.3. Развертывание веб-сервера Caddy
Создайте конфигурацию Docker Compose для SelfSteel:
```bash
nano docker-compose.yml
```

Вставьте конфигурацию службы:
```yaml
services:
  caddy:
    image: caddy:latest
    container_name: caddy-remnawave
    restart: unless-stopped
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ../html:/var/www/html
      - ./logs:/var/log/caddy
      - caddy_data_selfsteal:/data
      - caddy_config_selfsteal:/config
    env_file:
      - .env
    network_mode: "host"

volumes:
  caddy_data_selfsteal:
  caddy_config_selfsteal:
```

Запустите Caddy:
```bash
docker compose up -d
```

### Шаг 4.4. Создание сайта-заглушки (Фейк-сайт)
Перейдите в директорию веб-ресурсов и создайте стартовую HTML-страницу, которую будут видеть посторонние пользователи и сканеры:
```bash
mkdir -p /opt/html && cd /opt/html && nano index.html
```
*(Сюда можно вставить любой шаблонный HTML-код простого сайта, блога или визитки).*

### Шаблон index.html
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My Website</title>
</head>
<body>
    <h1>Welcome to My Website</h1>
    <p>This is the homepage.</p>
</body>
</html>
```
