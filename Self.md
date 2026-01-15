##Self - Мой конфиг с Ремны
```json
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "tag": "VLESS_REALITY_SELFSTEAL",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "flow": "xtls-rprx-vision",
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
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "xver": 0,
          "target": "127.0.0.1:9443",
          "spiderX": "/",
          "shortIds": [
            "",
            "9547c5e97f6a6a1f"
          ],
          "privateKey": "T6s-dE9dpeDL41fI6O0d9Mh5Dy40HUI7IhvlsTmUT9Y",
          "serverNames": [
            "interstellar.su"
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

```
