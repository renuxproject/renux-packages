if [ -z "$CHROOT_READY" ]; then
	CFLAGS+=" -isystem ${RENUXPKG_MASTERDIR}/usr/include"
	LDFLAGS+=" -L${RENUXPKG_MASTERDIR}/usr/lib -Wl,-rpath-link=${RENUXPKG_MASTERDIR}/usr/lib"
fi
