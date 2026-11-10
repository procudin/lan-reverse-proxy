#!/bin/sh
set -eu
root="${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$root/files/etc/init.d/lan-reverse-proxy"
procd_add_reload_trigger() { [ "$*" = lan_reverse_proxy ]; }
procd_add_raw_trigger() {
	[ "$*" = 'interface.* 1000 /etc/init.d/lan-reverse-proxy reload' ]
	interface_trigger=1
}
interface_trigger=0
service_triggers
[ "$interface_trigger" = 1 ]
printf 'Interface subscription is independent of the selected interface list\n'
