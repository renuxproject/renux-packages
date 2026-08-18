# fetch build_style: fetches and copies files to ${wrksrc}.

do_extract() {
	local f curfile

	mkdir -p "${wrksrc}"
	for f in ${distfiles}; do
		curfile="${f#*>}"
		curfile="${curfile##*/}"
		cp ${RENUXPKG_SRCDISTDIR}/${pkgname}-${version}/${curfile} "${wrksrc}/${curfile}"
	done
}
