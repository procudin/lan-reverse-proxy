#!/bin/sh

set -eu

root="${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
temporary="$(mktemp -d)"
backend_pid=
nginx_started=

cleanup() {
	if [ -n "$nginx_started" ]; then
		nginx -s stop -c "$temporary/nginx.conf" >/dev/null 2>&1 || true
	fi
	if [ -n "$backend_pid" ]; then
		kill "$backend_pid" >/dev/null 2>&1 || true
		wait "$backend_pid" >/dev/null 2>&1 || true
	fi
	rm -f "$temporary/nginx.conf" "$temporary/generated.conf" "$temporary/nginx.pid" "$temporary/backend.log" "$temporary/www/result.txt" "$temporary/config/lan_reverse_proxy" "$temporary/response.1" "$temporary/response.2" "$temporary/response.3"
	rmdir "$temporary/www" "$temporary/config" "$temporary"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

mkdir "$temporary/www" "$temporary/config"
printf 'proxy ok\n' > "$temporary/www/result.txt"
cat > "$temporary/config/lan_reverse_proxy" <<EOF
config lan_reverse_proxy 'main'
	option listen_port '41891'
	option active_server 'test'
	list interfaces 'lan'

config upstream 'test'
	option scheme 'http'
	option host '127.0.0.1'
	option port '41892'
EOF

uhttpd -f -c /dev/null -p 127.0.0.1:41892 -h "$temporary/www" > "$temporary/backend.log" 2>&1 &
backend_pid=$!
sleep 1
kill -0 "$backend_pid"

UCI_CONFIG_DIR="$temporary/config" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config" > "$temporary/generated.conf"
# Never use the production PID file, even when testing alongside a live service.
sed "s|^pid .*;|pid $temporary/nginx.pid;|" "$temporary/generated.conf" > "$temporary/nginx.conf"
nginx -t -c "$temporary/nginx.conf"
nginx -c "$temporary/nginx.conf"
nginx_started=1
sleep 1

lan_address="$(ubus call network.interface.lan status | jsonfilter -e '@["ipv4-address"][0].address')"
response="$(wget -qO- "http://$lan_address:41891/result.txt")"
[ "$response" = 'proxy ok' ]
pids=
for index in 1 2 3; do
	wget -qO "$temporary/response.$index" "http://$lan_address:41891/result.txt" &
	pids="$pids $!"
done
for pid in $pids; do
	wait "$pid"
done
for index in 1 2 3; do
	[ "$(cat "$temporary/response.$index")" = 'proxy ok' ]
done
printf 'Proxy request passed\n'
