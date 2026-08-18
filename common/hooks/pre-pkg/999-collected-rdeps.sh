# This hook displays resolved dependencies for a pkg.

hook() {
	if [ -e "${RENUXPKG_STATEDIR}/${pkgname}-rdeps" ]; then
		echo "   $(cat "${RENUXPKG_STATEDIR}/${pkgname}-rdeps")"
	fi
}
