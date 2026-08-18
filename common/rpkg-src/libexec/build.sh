#!/bin/bash
#
# vim: set ts=4 sw=4 et:
#
# Passed arguments:
#   $1 - current pkgname to build [REQUIRED]
#   $2 - target pkgname (origin) to build [REQUIRED]
#   $3 - renuxpkg target [REQUIRED]
#   $4 - cross target [OPTIONAL]
#   $5 - internal [OPTIONAL]

if [ $# -lt 3 -o $# -gt 5 ]; then
    echo "${0##*/}: invalid number of arguments: pkgname targetpkg target [cross-target]"
    exit 1
fi

readonly PKGNAME="$1"
readonly RENUXPKG_TARGET_PKG="$2"
readonly RENUXPKG_TARGET="$3"
readonly RENUXPKG_CROSS_BUILD="$4"
readonly RENUXPKG_CROSS_PREPARE="$5"

export RENUXPKG_TARGET

for f in $RENUXPKG_SHUTILSDIR/*.sh; do
    . $f
done

last="${RENUXPKG_DEPENDS_CHAIN##*,}"
case "$RENUXPKG_DEPENDS_CHAIN" in
    *,$last,*)
        msg_error "Build-time cyclic dependency$last,${RENUXPKG_DEPENDS_CHAIN##*,$last,} detected.\n"
esac

setup_pkg "$PKGNAME" $RENUXPKG_CROSS_BUILD
readonly SOURCEPKG="$sourcepkg"

check_existing_pkg

show_pkg_build_options
check_pkg_arch $RENUXPKG_CROSS_BUILD

if [ -z "$RENUXPKG_CROSS_PREPARE" ]; then
    prepare_cross_sysroot $RENUXPKG_CROSS_BUILD || exit $?
fi
# Install dependencies from binary packages
if [ "$PKGNAME" != "$RENUXPKG_TARGET_PKG" -o -z "$RENUXPKG_SKIP_DEPS" ]; then
    install_pkg_deps $PKGNAME $RENUXPKG_TARGET_PKG pkg $RENUXPKG_CROSS_BUILD $RENUXPKG_CROSS_PREPARE || exit $?
fi

if [ "$RENUXPKG_CROSS_BUILD" ]; then
    install_cross_pkg $RENUXPKG_CROSS_BUILD || exit $?
fi

# Fetch distfiles after installing required dependencies,
# because some of them might be required for do_fetch().
$RENUXPKG_LIBEXECDIR/rpkg-src-dofetch.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "fetch" ] && exit 0

# Fetch, extract, build and install into the destination directory.
$RENUXPKG_LIBEXECDIR/rpkg-src-doextract.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "extract" ] && exit 0

# Run patch phrase
$RENUXPKG_LIBEXECDIR/rpkg-src-dopatch.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "patch" ] && exit 0

# Run configure phase
$RENUXPKG_LIBEXECDIR/rpkg-src-doconfigure.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "configure" ] && exit 0

# Run build phase
$RENUXPKG_LIBEXECDIR/rpkg-src-dobuild.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "build" ] && exit 0

# Run check phase
$RENUXPKG_LIBEXECDIR/rpkg-src-docheck.sh $SOURCEPKG $RENUXPKG_CROSS_BUILD || exit 1
[ "$RENUXPKG_TARGET" = "check" ] && exit 0

# Install pkgs into destdir.
$RENUXPKG_LIBEXECDIR/rpkg-src-doinstall.sh $SOURCEPKG no $RENUXPKG_CROSS_BUILD || exit 1

for subpkg in ${subpackages} ${sourcepkg}; do
    $RENUXPKG_LIBEXECDIR/rpkg-src-doinstall.sh $subpkg yes $RENUXPKG_CROSS_BUILD || exit 1
done
for subpkg in ${subpackages} ${sourcepkg}; do
    $RENUXPKG_LIBEXECDIR/rpkg-src-prepkg.sh $subpkg $RENUXPKG_CROSS_BUILD || exit 1
done

for subpkg in ${subpackages} ${sourcepkg}; do
    if [ "$PKGNAME" = "${subpkg}" -a "$RENUXPKG_TARGET" = "install" ]; then
        exit 0
    fi
done

# Clean list of preregistered packages
printf "" > ${RENUXPKG_STATEDIR}/.${sourcepkg}_register_pkg
# If install went ok generate the binpkgs.
for subpkg in ${subpackages} ${sourcepkg}; do
    $RENUXPKG_LIBEXECDIR/rpkg-src-dopkg.sh $subpkg "$RENUXPKG_REPOSITORY" "$RENUXPKG_CROSS_BUILD" || exit 1
done

# Registering packages at once per repository. This makes sure that staging is
# triggered for all new packages if any of them introduces inconsistencies.
cut -d: -f 1,2 ${RENUXPKG_STATEDIR}/.${sourcepkg}_register_pkg | sort -u | \
    while IFS=: read -r arch repo; do
        paths=$(grep "^$arch:$repo:" "${RENUXPKG_STATEDIR}/.${sourcepkg}_register_pkg" | \
            cut -d : -f 2,3 | tr ':' '/')
        if [ -z "$RENUXPKG_PRESERVE_PKGS" ] || [ "$RENUXPKG_BUILD_FORCEMODE" ]; then
            force=-f
        fi
        if [ -n "${arch}" ]; then
            msg_normal "Registering new packages to $repo ($arch)\n"
            RENUXPKG_TARGET_ARCH=${arch} $RENUXPKG_RINDEX_CMD \
                ${RENUXPKG_REPO_COMPTYPE:+--compression $RENUXPKG_REPO_COMPTYPE} ${force} -a ${paths}
        else
            msg_normal "Registering new packages to $repo\n"
            if [ -n "$RENUXPKG_CROSS_BUILD" ]; then
                $RENUXPKG_RINDEX_XCMD ${RENUXPKG_REPO_COMPTYPE:+--compression $RENUXPKG_REPO_COMPTYPE} \
					${force} -a ${paths}
            else
                $RENUXPKG_RINDEX_CMD ${RENUXPKG_REPO_COMPTYPE:+--compression $RENUXPKG_REPO_COMPTYPE} \
					${force} -a ${paths}
            fi
        fi
    done

# pkg cleanup
if declare -f do_clean >/dev/null; then
    run_func do_clean
fi

if [ -n "$RENUXPKG_DEPENDENCY" -o -z "$RENUXPKG_KEEP_ALL" ]; then
    remove_pkg_autodeps
    remove_pkg_wrksrc
    remove_pkg $RENUXPKG_CROSS_BUILD
    remove_pkg_statedir
fi

exit 0
