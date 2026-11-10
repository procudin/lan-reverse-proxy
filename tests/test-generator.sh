#!/bin/sh

set -eu

root="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
temporary="$(mktemp -d)"
trap 'rm -f "$temporary/lan_reverse_proxy" "$temporary/nginx.conf"; rmdir "$temporary"' EXIT HUP INT TERM

cp "$root/tests/valid-config" "$temporary/lan_reverse_proxy"
generated="$(UCI_CONFIG_DIR="$temporary" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config")"
case "$generated" in
	*'proxy_set_header Authorization "Basic dGVzdDp0ZXN0";'*) ;;
	*) exit 1 ;;
esac
case "$generated" in
	*'https://example.com:443'*) ;;
	*) exit 1 ;;
esac
case "$generated" in
	*'unused.example.com'*) exit 1 ;;
esac
printf '%s\n' "$generated" > "$temporary/nginx.conf"
nginx -t -c "$temporary/nginx.conf"

cp "$root/tests/no-auth-config" "$temporary/lan_reverse_proxy"
generated="$(UCI_CONFIG_DIR="$temporary" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config")"
case "$generated" in
	*'proxy_set_header Authorization "";'*) ;;
	*) exit 1 ;;
esac
printf '%s\n' "$generated" > "$temporary/nginx.conf"
nginx -t -c "$temporary/nginx.conf"

cp "$root/tests/no-active-config" "$temporary/lan_reverse_proxy"
generated="$(UCI_CONFIG_DIR="$temporary" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config")"
case "$generated" in
	*'return 503;'*) ;;
	*) exit 1 ;;
esac
printf '%s\n' "$generated" > "$temporary/nginx.conf"
nginx -t -c "$temporary/nginx.conf"

cp "$root/tests/invalid-host-config" "$temporary/lan_reverse_proxy"
if UCI_CONFIG_DIR="$temporary" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config" > /dev/null 2>&1; then
	exit 1
fi
