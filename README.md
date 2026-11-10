# LAN Reverse Proxy

A lightweight nginx reverse proxy for OpenWrt with LuCI configuration.

- HTTP and HTTPS upstream profiles with manual switching.
- Optional upstream Basic Auth and TLS certificate verification.
- Access restricted to selected network subnets.
- Streaming, WebSocket and HTTP range support.

# Installation

```sh
wget -O /tmp/lanrp-install.sh https://github.com/procudin/lan-reverse-proxy/releases/latest/download/install.sh && sh /tmp/lanrp-install.sh
```
