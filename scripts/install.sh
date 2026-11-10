#!/bin/sh
set -eu

repository="${1:-procudin/lan-reverse-proxy}"
case "$repository" in
    ''|*[!A-Za-z0-9_./-]*|*..*) echo 'Usage: sh install.sh OWNER/REPO' >&2; exit 1 ;;
esac
[ "$(id -u)" = 0 ] || { echo 'Run as root.' >&2; exit 1; }
command -v apk >/dev/null || { echo 'OpenWrt with apk is required.' >&2; exit 1; }
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
download() {
    if command -v curl >/dev/null; then
        curl -fLsS --retry 3 "$1" -o "$2"
    else
        wget -O "$2" "$1"
    fi
}
base="https://github.com/$repository/releases/latest/download"
download "$base/SHA256SUMS" "$temporary/SHA256SUMS"
# Fetch the versioned artifact named in the checksum file, from its immutable tag.
package="$(awk 'NR == 1 { print $2 }' "$temporary/SHA256SUMS")"
case "$package" in
    luci-app-lan-reverse-proxy-*.apk) ;;
    *) echo 'Invalid release manifest.' >&2; exit 1 ;;
esac
case "$package" in *[!A-Za-z0-9._-]*) exit 1 ;; esac
version="${package#luci-app-lan-reverse-proxy-}"
version="${version%.apk}"
download "https://github.com/$repository/releases/download/v$version/$package" "$temporary/$package"
(cd "$temporary" && sha256sum -c SHA256SUMS)
apk add --allow-untrusted "$temporary/$package"
/etc/init.d/lan-reverse-proxy enable
/etc/init.d/lan-reverse-proxy reload
/etc/init.d/lan-reverse-proxy running
