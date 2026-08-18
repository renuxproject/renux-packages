#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#	$1 - pkgname to build [REQUIRED]
#	$2 - cross target [OPTIONAL]

if [ $# -lt 1 -o $# -gt 2 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname [cross-target]"
    exit 1
fi

PKGNAME="$1"
RENUXPKG_CROSS_BUILD="$2"

for f in $RENUXPKG_SHUTILSDIR/*.sh; do
    . $f
done

setup_pkg "$PKGNAME" $RENUXPKG_CROSS_BUILD

if [ -n "$disable_parallel_check" ]; then
    RENUXPKG_MAKEJOBS=1
else
    RENUXPKG_MAKEJOBS="$RENUXPKG_ORIG_MAKEJOBS"
fi
makejobs="-j$RENUXPKG_MAKEJOBS"

RENUXPKG_CHECK_DONE="${RENUXPKG_STATEDIR}/${sourcepkg}_${RENUXPKG_CROSS_BUILD}_check_done"

if [ -n "$RENUXPKG_CROSS_BUILD" ]; then
    msg_normal "${pkgname}-${version}_${revision}: skipping check (cross build for $RENUXPKG_CROSS_BUILD) ...\n"
    exit 0
fi

if [ -z "$RENUXPKG_CHECK_PKGS" ]; then
    msg_normal "${pkgname}-${version}_${revision}: skipping check (RENUXPKG_CHECK_PKGS is disabled) ...\n"
    exit 0
fi

if [ "$make_check" = no ]; then
    msg_normal "${pkgname}-${version}_${revision}: skipping check (make_check=no) ...\n"
    exit 0
fi

if [ "$make_check" = extended -a "$RENUXPKG_CHECK_PKGS" != full ]; then
    msg_normal \
        "${pkgname}-${version}_${revision}: skipping check (make_check=extended and RENUXPKG_CHECK_PKGS is not 'full') ...\n"
    exit 0
fi

if [ "$make_check" = ci-skip ] && [ "$RENUXPKG_BUILD_ENVIRONMENT" = renux-packages-ci ]; then
    msg_warn \
        "${pkgname}-${version}_${revision}: skipping here because of make_check=ci-skip. Tests should be run locally.\n"
    exit 0
fi

for f in $RENUXPKG_COMMONDIR/environment/check/*.sh; do
    source_file "$f"
done

run_step check optional

touch -f $RENUXPKG_CHECK_DONE

exit 0
