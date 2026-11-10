#!/usr/bin/env bash

set -euo pipefail

version="25.12.6"
target="mediatek/filogic"
archive_name="openwrt-sdk-${version}-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst"
archive_sha256="1c04ac47bdfc361d6aab299eb520d570e368013dedcb8d29cf39dc7168ae642e"
base_url="https://downloads.cdn.openwrt.org/releases/${version}/targets/${target}"
cache_root="${CACHE_DIR:-/cache}"
download_dir="${cache_root}/downloads"
sdk_dir="${cache_root}/sdk/${version}-mediatek-filogic"
apk="${sdk_dir}/staging_dir/host/bin/apk"
output_dir="/work/out"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
stage="$build_dir/root"

mkdir -p "$download_dir" "$sdk_dir"
archive="${download_dir}/${archive_name}"
if [ ! -s "$archive" ]; then
	curl -fL --retry 3 "$base_url/$archive_name" -o "$archive.part"
	mv "$archive.part" "$archive"
fi
printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum -c -

if [ ! -f "$sdk_dir/.ready" ] || [ "$(cat "$sdk_dir/.ready")" != "$archive_sha256" ]; then
	tar --zstd -xf "$archive" -C "$sdk_dir" --strip-components=1
	printf '%s\n' "$archive_sha256" > "$sdk_dir/.ready"
fi

if [ ! -x "$apk" ]; then
	FORCE_UNSAFE_CONFIGURE=1 make -C "$sdk_dir" package/system/apk/host/compile
fi

pkg_name="$(sed -n 's/^PKG_NAME:=//p' /work/Makefile)"
pkg_version="$(sed -n 's/^PKG_VERSION:=//p' /work/Makefile)"
pkg_release="$(sed -n 's/^PKG_RELEASE:=//p' /work/Makefile)"
pkg_license="$(sed -n 's/^PKG_LICENSE:=//p' /work/Makefile)"
pkg_title="$(sed -n 's/^  TITLE:=//p' /work/Makefile)"
pkg_depends="$(sed -n 's/^[[:space:]]*DEPENDS:=[[:space:]]*//p' /work/Makefile | tr ' ' '\n' | sed 's/^+//' | sed '/^$/d' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
[ -n "$pkg_name" ] && [ -n "$pkg_version" ] && [ -n "$pkg_release" ] && [ -n "$pkg_license" ] && [ -n "$pkg_depends" ]

mkdir -p "$stage"
install -D -m 600 /work/files/etc/config/lan_reverse_proxy "$stage/etc/config/lan_reverse_proxy"
install -D -m 755 /work/files/etc/init.d/lan-reverse-proxy "$stage/etc/init.d/lan-reverse-proxy"
install -D -m 755 /work/files/usr/lib/lan-reverse-proxy/generate-config "$stage/usr/lib/lan-reverse-proxy/generate-config"
install -D -m 644 /work/files/usr/share/luci/menu.d/luci-app-lan-reverse-proxy.json "$stage/usr/share/luci/menu.d/luci-app-lan-reverse-proxy.json"
install -D -m 644 /work/files/usr/share/rpcd/acl.d/luci-app-lan-reverse-proxy.json "$stage/usr/share/rpcd/acl.d/luci-app-lan-reverse-proxy.json"
install -D -m 644 /work/files/www/luci-static/resources/view/lan-reverse-proxy/config.js "$stage/www/luci-static/resources/view/lan-reverse-proxy/config.js"

# Match the OpenWrt SDK lifecycle hooks and the file list used by its helpers.
mkdir -p "$stage/lib/apk/packages"
(cd "$stage" && find . -type f -printf '/%P\n' | sort) > "$stage/lib/apk/packages/$pkg_name.list"
printf '/etc/config/lan_reverse_proxy\n' > "$stage/lib/apk/packages/$pkg_name.conffiles"
printf '/etc/config/lan_reverse_proxy %s\n' "$(sha256sum "$stage/etc/config/lan_reverse_proxy" | cut -d ' ' -f 1)" > "$stage/lib/apk/packages/$pkg_name.conffiles_static"
for hook in post-install post-upgrade pre-deinstall; do
	{
		printf '#!/bin/sh\n'
		[ "$hook" != post-upgrade ] || printf 'export PKG_UPGRADE=1\n'
		printf '[ "$IPKG_NO_SCRIPT" = 1 ] && exit 0\n'
		printf '[ -s "$IPKG_INSTROOT/lib/functions.sh" ] || exit 0\n'
		printf '. "$IPKG_INSTROOT/lib/functions.sh"\n'
		printf 'export root="$IPKG_INSTROOT"\n'
		printf "export pkgname='%s'\n" "$pkg_name"
		if [ "$hook" = pre-deinstall ]; then
			printf 'default_prerm\n'
		else
			printf 'add_group_and_user\ndefault_postinst\n'
		fi
	} > "$build_dir/$hook"
done

package_file="${output_dir}/${pkg_name}-${pkg_version}-r${pkg_release}.apk"
temporary_package="/tmp/${pkg_name}-${pkg_version}-r${pkg_release}.apk"
mkdir -p "$output_dir"
"$apk" mkpkg \
	--files "$stage" \
	--output "$temporary_package" \
	--script "post-install:$build_dir/post-install" \
	--script "post-upgrade:$build_dir/post-upgrade" \
	--script "pre-deinstall:$build_dir/pre-deinstall" \
	--info "name:${pkg_name}" \
	--info "version:${pkg_version}-r${pkg_release}" \
	--info "arch:noarch" \
	--info "license:${pkg_license}" \
	--info "description:${pkg_title}" \
	--info "origin:${pkg_name}" \
	--info "depends:${pkg_depends}"
"$apk" adbdump "$temporary_package" > /dev/null

cp "$temporary_package" "$package_file"
printf 'Built package: %s\n' "$package_file"
