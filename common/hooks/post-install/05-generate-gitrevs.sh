# This hook generates a file ${RENUXPKG_STATEDIR}/gitrev with the last
# commit sha1 (in short mode) for source pkg if RENUXPKG_USE_GIT_REVS is enabled.

hook() {
	local GITREVS_FILE=${RENUXPKG_STATEDIR}/gitrev

	# If RENUXPKG_USE_GIT_REVS is disabled in conf file don't continue.
	if [ -z $RENUXPKG_USE_GIT_REVS ]; then
		return
	fi
	# If the file exists don't regenerate it again.
	if [ -s ${GITREVS_FILE} ]; then
		return
	fi

	if [ -z "$RENUXPKG_GIT_REVS" ]; then
		msg_error "BUG: RENUXPKG_GIT_REVS is not set\n"
	fi

	cd $RENUXPKG_SRCPKGDIR
	echo "${sourcepkg}:${RENUXPKG_GIT_REVS}"
	echo "${sourcepkg}:${RENUXPKG_GIT_REVS}" > $GITREVS_FILE
}
