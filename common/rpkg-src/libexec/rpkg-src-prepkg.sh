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

for f in $RENUXPKG_COMMONDIR/environment/install/*.sh; do
    source_file "$f"
done


RENUXPKG_PREPKG_DONE="${RENUXPKG_STATEDIR}/${PKGNAME}_${RENUXPKG_CROSS_BUILD}_prepkg_done"

if [ -z "$RENUXPKG_BUILD_FORCEMODE" -a -f $RENUXPKG_PREPKG_DONE ]; then
    exit 0
fi

# If it's a subpkg execute the pkg_install() function.
if [ "$sourcepkg" != "$PKGNAME" ]; then
    # Source all subpkg environment setup snippets.
    for f in ${RENUXPKG_COMMONDIR}/environment/setup-subpkg/*.sh; do
        source_file "$f"
    done

    ${PKGNAME}_package
    pkgname=$PKGNAME
fi

source_file $RENUXPKG_COMMONDIR/environment/build-style/${build_style}.sh
setup_pkg_depends $pkgname || exit 1
run_pkg_hooks pre-pkg

touch -f $RENUXPKG_PREPKG_DONE

exit 0
