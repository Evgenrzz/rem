##Bridge Profile out
```bash
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {},
  "inbounds": [
    {
      "tag": "BRIDGE_DE_IN",
      "port": 9999,
      "listen": "0.0.0.0",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [],
        "network": "tcp,udp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
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
    "rules": []
  }
}
```











##Bridge
```bash
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "tag": "PUBLIC_RU_INBOUND",
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
        "xhttpSettings": {
          "host": "kinopoisk.ru",
          "mode": "auto",
          "path": "/api/v2/stream"
        },
        "realitySettings": {
          "show": false,
          "xver": 0,
          "target": "kinopoisk.ru:443",
          "shortIds": [
            ""
          ],
          "privateKey": "Dg7ltW8Cae1IgfeUgCwvWfzamwURJVJNNEbXagPPCVY",
          "serverNames": [
            "kinopoisk.ru",
            "www.kinopoisk.ru"
          ]
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
    },
    {
      "tag": "SS_OUTBOUND_TO_DE",
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "port": 9999,
            "email": "bridge_user_001",
            "level": 0,
            "method": "chacha20-ietf-poly1305",
            "address": "nl-2.xorekvpn.net",
            "password": "TzsXHhvpvhcZjuwMn5dxdb7u99htcp3x"
          }
        ]
      }
    }
  ],
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "domain": [
          "geosite:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "ip": [
          "geoip:ru"
        ],
        "outboundTag": "DIRECT"
      },
      {
        "domain": [
          "geosite:category-ru"
        ],
        "outboundTag": "DIRECT"
      },
      {
        "inboundTag": [
          "PUBLIC_RU_INBOUND"
        ],
        "outboundTag": "SS_OUTBOUND_TO_DE"
      }
    ]
  }
}
```
