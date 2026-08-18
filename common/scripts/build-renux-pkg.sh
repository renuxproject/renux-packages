#!/bin/bash
#
# Build a Renux binary package from a srcpkgs template by cross-compiling
# with zig cc targeting x86_64-freebsd against a FreeBSD base sysroot.
#
# Required environment:
#   RENUX_SYSROOT   path to an extracted FreeBSD base.txz sysroot
#   RENUXPKG_ARCH   target architecture (default: amd64)
#   PATH            must include zig and the rpkg tools (rpkg-create,
#                   rpkg-rindex)
#
# Usage: build-renux-pkg.sh <pkgname> [outdir]

set -e

: "${RENUX_SYSROOT:?RENUX_SYSROOT must point to a FreeBSD base sysroot}"
: "${RENUXPKG_ARCH:=amd64}"
: "${RENUXPKG_PREFIX:=/usr/local}"

pkg="$1"
outdir="${2:-hostdir/binpkgs/${RENUXPKG_ARCH}}"
template="srcpkgs/${pkg}/template"

if [ $# -lt 1 ]; then
    echo "usage: $0 <pkgname> [outdir]" >&2
    exit 1
fi
if [ ! -f "$template" ]; then
    echo "error: template not found: $template" >&2
    exit 1
fi
for t in rpkg-create rpkg-rindex; do
    command -v "$t" >/dev/null || { echo "error: $t not found in PATH" >&2; exit 1; }
done
command -v zig >/dev/null || { echo "error: zig not found in PATH" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Load the package template.
# ---------------------------------------------------------------------------
. "$template"

: "${pkgname:?template must set pkgname}"
: "${version:?template must set version}"
: "${revision:=1}"
: "${build_style:=gnu-configure}"

case "${RENUXPKG_ARCH}" in
    amd64)  host_triplet="x86_64-unknown-freebsd"; zig_target="x86_64-freebsd" ;;
    aarch64) host_triplet="aarch64-unknown-freebsd"; zig_target="aarch64-freebsd" ;;
    *) echo "error: unsupported RENUXPKG_ARCH: ${RENUXPKG_ARCH}" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Work directories.
# ---------------------------------------------------------------------------
repo_root="$(pwd -P)"
srcdir="${repo_root}/hostdir/sources"
builddir="${repo_root}/hostdir/build"
destdir="${repo_root}/hostdir/dest/${pkgname}-${version}"
wrksrc="${builddir}/${wrksrc:-${pkgname}-${version}}"
pkgver="${pkgname}-${version}_${revision}"
binpkg="${pkgver}.${RENUXPKG_ARCH}.rpkg"

mkdir -p "$srcdir" "$builddir" "$outdir"

# ---------------------------------------------------------------------------
# Cross-compile environment against the FreeBSD sysroot.
#
# FreeBSD ships lib<name>.so as a GNU ld linker script (INPUT(...)) which
# the zig linker cannot read, so create plain symlinks to the versioned
# libraries in <sysroot>/link and place it first on the link path.
# ---------------------------------------------------------------------------
if [ ! -d "${RENUX_SYSROOT}/link" ]; then
    mkdir -p "${RENUX_SYSROOT}/link"
    for f in "${RENUX_SYSROOT}"/usr/lib/*.so; do
        [ -f "$f" ] || continue
        if grep -q '^INPUT(' "$f" 2>/dev/null; then
            real=$(grep -oE '/lib/[A-Za-z0-9._-]+\.so\.[0-9]+' "$f" | head -1)
            real=${real#/lib/}
            if [ -n "$real" ] && [ -f "${RENUX_SYSROOT}/lib/${real}" ]; then
                ln -sf "../lib/${real}" "${RENUX_SYSROOT}/link/$(basename "$f")"
            fi
        fi
    done
fi

export CC="zig cc -target ${zig_target}"
export CXX="zig c++ -target ${zig_target}"
export CPPFLAGS="-I${RENUX_SYSROOT}/usr/include"
export LDFLAGS="-L${RENUX_SYSROOT}/link -L${RENUX_SYSROOT}/usr/lib -L${RENUX_SYSROOT}/lib"
export PKG_CONFIG_LIBDIR="${RENUX_SYSROOT}/usr/libdata/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${RENUX_SYSROOT}"

makejobs="-j$(nproc 2>/dev/null || echo 2)"

# ---------------------------------------------------------------------------
# Fetch and verify distfiles.
# ---------------------------------------------------------------------------
for d in ${distfiles}; do
    eval url="${d}"
    fname="${url##*/}"
    [ -f "${srcdir}/${fname}" ] || curl -fL -o "${srcdir}/${fname}" "$url"
    if [ -n "$checksum" ]; then
        (cd "$srcdir" && echo "${checksum}  ${fname}" | sha256sum -c -)
    fi
done

# ---------------------------------------------------------------------------
# Extract.
# ---------------------------------------------------------------------------
rm -rf "$wrksrc"
mkdir -p "$wrksrc"
for d in ${distfiles}; do
    eval url="${d}"
    fname="${url##*/}"
    case "$fname" in
        *.tar.*|*.tgz|*.tbz|*.txz)
            tar -xf "${srcdir}/${fname}" -C "$wrksrc" ;;
        *.zip)
            unzip -q -o "${srcdir}/${fname}" -d "$wrksrc" ;;
        *) echo "error: unsupported distfile format: $fname" >&2; exit 1 ;;
    esac
done

# If the archive unpacked to a single subdirectory, use it as the source dir
# (unless the template explicitly set wrksrc).
if [ "$wrksrc" = "${builddir}/${pkgname}-${version}" ]; then
    for entry in "${builddir}/${pkgname}-${version}"/*; do
        if [ -d "$entry" ] && [ -z "$(find "${builddir}/${pkgname}-${version}" -mindepth 1 -maxdepth 1 ! -path "$entry" -print -quit)" ]; then
            wrksrc="$entry"
            break
        fi
    done
fi
[ -d "$wrksrc" ] || { echo "error: no source directory found for ${pkgname}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Build.
# ---------------------------------------------------------------------------
rm -rf "$destdir"
mkdir -p "$destdir"

case "$build_style" in
    gnu-configure)
        (cd "$wrksrc" \
            && ./configure --host="$host_triplet" --prefix="${RENUXPKG_PREFIX}" ${configure_args} \
            && make ${makejobs} ${make_build_args} \
            && make ${makejobs} ${make_install_args} install DESTDIR="$destdir")
        ;;
    *)
        echo "error: unsupported build_style: ${build_style}" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Create the binary package (rpkg-create writes to the current directory).
# ---------------------------------------------------------------------------
(cd "$outdir" \
    && rpkg-create \
        ${dependencies:+--dependencies "${dependencies}"} \
        ${conf_files:+--config-files "${conf_files}"} \
        --architecture "${RENUXPKG_ARCH}" \
        --homepage "${homepage}" \
        --license "${license}" \
        --maintainer "${maintainer}" \
        --desc "${short_desc}" \
        --pkgver "${pkgver}" \
        --sourcepkg "${pkgname}" \
        --quiet \
        "$destdir")

echo "built ${outdir}/${binpkg}"