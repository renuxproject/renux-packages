# If RENUXPKG_USE_BUILD_MTIME is enabled in conf file don't continue.
# only run this, if SOURCE_DATE_EPOCH isn't set.

if [ -z "$RENUXPKG_GIT_CMD" ]; then
	if [ -z "$RENUXPKG_USE_BUILD_MTIME" ] || [ -n "$RENUXPKG_USE_GIT_REVS" ]; then
		msg_error "BUG: environment/setup: RENUXPKG_GIT_CMD is not set\n"
	fi
fi

if [ -n "$RENUXPKG_USE_BUILD_MTIME" ]; then
	unset SOURCE_DATE_EPOCH
elif [ -z "${SOURCE_DATE_EPOCH}" ]; then
	if [ -n "$IN_CHROOT" ]; then
		msg_error "rpkg-src's BUG: SOURCE_DATE_EPOCH is undefined\n"
	fi
	# check if the template is under version control:
	if [ -n "$basepkg" -a -z "$($RENUXPKG_GIT_CMD -C ${RENUXPKG_SRCPKGDIR}/${basepkg} ls-files template)" ]; then
		export SOURCE_DATE_EPOCH="$(stat_mtime ${RENUXPKG_SRCPKGDIR}/${basepkg}/template)"
	else
		export SOURCE_DATE_EPOCH=$($RENUXPKG_GIT_CMD -C ${RENUXPKG_DISTDIR} cat-file commit HEAD |
			sed -n '/^committer /{s/.*> \([0-9][0-9]*\) [-+][0-9].*/\1/p;q;}')
	fi
fi

# if RENUXPKG_USE_GIT_REVS is enabled in conf file,
# compute RENUXPKG_GIT_REVS to use in pkg hooks
if [ -z "$RENUXPKG_USE_GIT_REVS" ]; then
	unset RENUXPKG_GIT_REVS
elif [ -z "$RENUXPKG_GIT_REVS" ]; then
	if [ -n "$IN_CHROOT" ]; then
		msg_error "rpkg-src's BUG: RENUXPKG_GIT_REVS is undefined\n"
	else
		export RENUXPKG_GIT_REVS="$($RENUXPKG_GIT_CMD -C "${RENUXPKG_DISTDIR}" rev-parse --verify --short HEAD)"
	fi
fi
