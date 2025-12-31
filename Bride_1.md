----------------------------
Bridge Profile out
--------------------------------
```bash
{
  "log": {
    "loglevel": "warning"
  },
  "dns": {},
  "inbounds": [
    {
      "tag": "BRIDGE_NL_IN2",
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











----------------------------------
Bridge [RU]
---------------------------------
```bash
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "tag": "PUBLIC_RU_INBOUND2",
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
            "",
            "02a5283fd45ac213"
          ],
          "privateKey": "1tRwfdVmSk9wU-aG1V3uTmGLTgMaLpV-OK60UDKhkzc",
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
      "tag": "SS_OUTBOUND_TO_NL2",
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "port": 9999,
            "email": "bridge_user_002",
            "level": 0,
            "method": "chacha20-ietf-poly1305",
            "address": "nl-3.xorekvpn.net",
            "password": "xhytMTJUq-y0UWKKCbYpQh3mpBzJSRX3"
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
          "PUBLIC_RU_INBOUND2"
        ],
        "outboundTag": "SS_OUTBOUND_TO_NL2"
      }
    ]
  }
}
```
