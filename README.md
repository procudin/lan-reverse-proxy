# LAN Reverse Proxy

A lightweight nginx reverse proxy for OpenWrt with LuCI configuration.

- HTTP and HTTPS upstream profiles with manual switching.
- Optional upstream Basic Auth and TLS certificate verification.
- Access restricted to selected network subnets.
- Streaming, WebSocket and HTTP range support.

# Installation

```sh
wget -O /tmp/luci-app-lan-reverse-proxy.apk https://github.com/procudin/lan-reverse-proxy/releases/latest/download/luci-app-lan-reverse-proxy.apk && apk add --allow-untrusted /tmp/luci-app-lan-reverse-proxy.apk
```
