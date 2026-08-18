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

RENUXPKG_BUILD_DONE="${RENUXPKG_STATEDIR}/${sourcepkg}_${RENUXPKG_CROSS_BUILD}_build_done"

if [ -f $RENUXPKG_BUILD_DONE -a -z "$RENUXPKG_BUILD_FORCEMODE" ] ||
   [ -f $RENUXPKG_BUILD_DONE -a -n "$RENUXPKG_BUILD_FORCEMODE" -a $RENUXPKG_TARGET != "build" ]; then
    exit 0
fi

for f in $RENUXPKG_COMMONDIR/environment/build/*.sh; do
    source_file "$f"
done

run_step build optional

touch -f $RENUXPKG_BUILD_DONE

exit 0
