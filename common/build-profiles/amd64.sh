# Native build profile for Renux (FreeBSD) amd64 (x86_64).
#
# RENUXPKG_MACHINE comes from `rpkg-uhelper arch` (uname -m), which on
# FreeBSD/Renux x86_64 reports "amd64".

RENUXPKG_TARGET_CFLAGS="-mtune=generic"
RENUXPKG_TARGET_CXXFLAGS="$RENUXPKG_TARGET_CFLAGS"
RENUXPKG_TARGET_FFLAGS="$RENUXPKG_TARGET_CFLAGS"
RENUXPKG_TRIPLET="x86_64-unknown-freebsd"
RENUXPKG_ZIG_TARGET="x86_64-freebsd"
RENUXPKG_ZIG_CPU="baseline"