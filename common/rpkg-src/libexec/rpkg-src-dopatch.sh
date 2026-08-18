#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#	$1 - pkgname [REQUIRED]
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

RENUXPKG_PATCH_DONE="${RENUXPKG_STATEDIR}/${sourcepkg}_${RENUXPKG_CROSS_BUILD}_patch_done"

if [ -f $RENUXPKG_PATCH_DONE ]; then
    exit 0
fi

for f in $RENUXPKG_COMMONDIR/environment/patch/*.sh; do
    source_file "$f"
done

run_step patch optional

touch -f $RENUXPKG_PATCH_DONE

exit 0
