# Cross build profile for Renux (FreeBSD) amd64 (x86_64).
#
# Cross-compiling to Renux is done with zig (zig cc), which bundles the
# FreeBSD libc and headers. The produced binaries link against the FreeBSD
# base system libraries already present in Renux.

RENUXPKG_TARGET_MACHINE="amd64"
RENUXPKG_TARGET_QEMU_MACHINE="x86_64"
RENUXPKG_CROSS_TRIPLET="x86_64-unknown-freebsd"
RENUXPKG_CROSS_CFLAGS="-mtune=generic"
RENUXPKG_CROSS_CXXFLAGS="$RENUXPKG_CROSS_CFLAGS"
RENUXPKG_CROSS_FFLAGS="$RENUXPKG_CROSS_CFLAGS"
RENUXPKG_CROSS_ZIG_TARGET="x86_64-freebsd"
RENUXPKG_CROSS_ZIG_CPU="baseline"