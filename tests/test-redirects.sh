#!/bin/sh
set -eu
root="${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
temporary="$(mktemp -d)"
started=
cleanup() {
	[ -z "$started" ] || nginx -s stop -c "$temporary/nginx.conf" >/dev/null 2>&1 || true
	rm -f "$temporary/lan_reverse_proxy" "$temporary/generated.conf" "$temporary/nginx.conf" "$temporary/nginx.pid"
	rmdir "$temporary"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
for pair in http:80 https:443; do
	scheme="${pair%:*}"
	port="${pair#*:}"
	cat > "$temporary/lan_reverse_proxy" <<EOF
config lan_reverse_proxy 'main'
	option listen_port '41893'
	option active_server 'test'
config upstream 'test'
	option scheme '$scheme'
	option host 'example.com'
	option port '$port'
EOF
	UCI_CONFIG_DIR="$temporary" sh "$root/files/usr/lib/lan-reverse-proxy/generate-config" > "$temporary/generated.conf"
	# Only the test transport is replaced; redirect rules come from the generator.
	sed -e "s|^pid .*;|pid $temporary/nginx.pid;|" \
		-e '/deny all;/i\        allow 127.0.0.1;' \
		-e 's|proxy_pass .*;|proxy_pass http://127.0.0.1:41894;|' \
		-e "\$i\\    server { listen 127.0.0.1:41894; location /implicit { return 302 $scheme://example.com/next; } location /explicit { return 302 $scheme://example.com:$port/next; } location /external { return 302 $scheme://other.example/next; } }" \
		"$temporary/generated.conf" > "$temporary/nginx.conf"
	nginx -t -c "$temporary/nginx.conf"
	nginx -c "$temporary/nginx.conf"
	started=1
	for path in implicit explicit; do
		location="$(curl --fail --silent --show-error --max-time 5 -o /dev/null -w '%{redirect_url}' "http://127.0.0.1:41893/$path")"
		[ "$location" = 'http://127.0.0.1:41893/next' ]
	done
	location="$(curl --fail --silent --show-error --max-time 5 -o /dev/null -w '%{redirect_url}' http://127.0.0.1:41893/external)"
	[ "$location" = "$scheme://other.example/next" ]
	nginx -s quit -c "$temporary/nginx.conf"
	for attempt in 1 2 3 4 5; do
		[ -f "$temporary/nginx.pid" ] || break
		sleep 1
	done
	[ ! -f "$temporary/nginx.pid" ]
	started=
done
printf 'HTTP/HTTPS redirects passed (implicit, explicit, external)\n'
