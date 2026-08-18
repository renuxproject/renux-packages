#
# This helper is for templates installing ruby modules.
#

do_install() {
	local _vendorlibdir=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')

	if [ "$RENUXPKG_WORDSIZE" != "$RENUXPKG_TARGET_WORDSIZE" ]; then
		_vendorlibdir="${_vendorlibdir//lib$RENUXPKG_WORDSIZE/lib$RENUXPKG_TARGET_WORDSIZE}"
	fi

	LANG=C ruby install.rb --destdir=${DESTDIR} --sitelibdir=${_vendorlibdir} ${make_install_args}
}
