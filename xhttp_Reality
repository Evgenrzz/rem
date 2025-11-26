Remnawave xhttp Reality (Рабочий) <br>
Вставьте (замените `ВСТАВЬТЕ_ВАШ_ПРИВАТНЫЙ_КЛЮЧ`):
```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "VLESS_XHTTP_REALITY",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.kinopoisk.ru:443",
          "show": false,
          "xver": 0,
          "spiderX": "/",
          "shortIds": [
            "",
            "39",
            "6ba85179e30d4fc2"
          ],
          "privateKey": "ВСТАВЬТЕ_ВАШ_ПРИВАТНЫЙ_КЛЮЧ",
          "fingerprint": "chrome",
          "serverNames": [
            "www.kinopoisk.ru",
            "kinopoisk.ru"
          ]
        },
        "xhttpSettings": {
          "mode": "auto",
          "path": "/api/v2/stream",
          "host": "www.kinopoisk.ru"
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "DIRECT",
      "protocol": "freedom"
    },
    {
      "tag": "BLOCK",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "type": "field",
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      }
    ]
  }
}
