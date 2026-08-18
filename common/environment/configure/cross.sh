if [ -n "$CROSS_BUILD" ]; then
	CFLAGS+=" -I${RENUXPKG_CROSS_BASE}/usr/include"
	CXXFLAGS+=" -I${RENUXPKG_CROSS_BASE}/usr/include"
	LDFLAGS+=" -L${RENUXPKG_CROSS_BASE}/usr/lib"
fi
