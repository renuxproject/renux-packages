# This snippet setups pkg-config vars.

if [ -z "$CHROOT_READY" ]; then
	export PKG_CONFIG_PATH="${RENUXPKG_MASTERDIR}/usr/lib/pkgconfig:${RENUXPKG_MASTERDIR}/usr/share/pkgconfig"
fi
