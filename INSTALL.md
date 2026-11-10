# Installation

On OpenWrt with apk, run as root:

```sh
wget -O /tmp/lanrp-install.sh https://github.com/procudin/lan-reverse-proxy/releases/latest/download/install.sh && sh /tmp/lanrp-install.sh
```

The installer verifies SHA-256 checksums, installs the unsigned APK with
`--allow-untrusted`, preserves existing configuration, and enables the service
and autostart. Configure upstreams under **Services > LAN Reverse Proxy** in LuCI.

Releases are published on pushes changing `Makefile` on the default branch when
`PKG_VERSION` or `PKG_RELEASE` identifies a release that does not exist yet.
Use **Actions > Release APK > Run workflow** for the initial release or a retry.
