# This build-helper sets up qmake’s cross environment
# in cases the build-style is mixed,
# e.g. when in a gnu-configure style the configure
# script calls qmake or a makefile in a gnu-makefile style,
# respectively.

if [ "$CROSS_BUILD" ]; then
	mkdir -p "${RENUXPKG_WRAPPERDIR}/qt5/target-spec/linux-g++"
	cat > "${RENUXPKG_WRAPPERDIR}/qt5/target-spec/linux-g++/qmake.conf" <<_EOF
MAKEFILE_GENERATOR      = UNIX
CONFIG                 += incremental no_qt_rpath
QMAKE_INCREMENTAL_STYLE = sublib

include(/usr/lib/qt5/mkspecs/common/linux.conf)
include(/usr/lib/qt5/mkspecs/common/gcc-base-unix.conf)
include(/usr/lib/qt5/mkspecs/common/g++-unix.conf)

QMAKE_TARGET_CONFIG     = ${RENUXPKG_CROSS_BASE}/usr/lib/qt5/mkspecs/qconfig.pri
QMAKE_TARGET_MODULE     = ${RENUXPKG_CROSS_BASE}/usr/lib/qt5/mkspecs/qmodule.pri
QMAKEMODULES            = ${RENUXPKG_CROSS_BASE}/usr/lib/qt5/mkspecs/modules
QMAKE_CC                = ${CC}
QMAKE_CXX               = ${CXX}
QMAKE_LINK              = ${CXX}
QMAKE_LINK_C            = ${CC}
QMAKE_LINK_SHLIB        = ${CXX}

QMAKE_AR                = ${RENUXPKG_CROSS_TRIPLET}-gcc-ar cqs
QMAKE_OBJCOPY           = ${OBJCOPY}
QMAKE_NM                = ${NM} -P
QMAKE_STRIP             = ${STRIP}

QMAKE_CFLAGS            = ${CFLAGS}
QMAKE_CXXFLAGS          = ${CXXFLAGS}
QMAKE_LFLAGS            = ${LDFLAGS}
load(qt_config)
_EOF
	echo "#include \"${RENUXPKG_CROSS_BASE}/usr/lib/qt5/mkspecs/linux-g++/qplatformdefs.h\"" > "${RENUXPKG_WRAPPERDIR}/qt5/target-spec/linux-g++/qplatformdefs.h"

	cat > "${RENUXPKG_WRAPPERDIR}/qt5.conf" <<_EOF
[Paths]
Sysroot=${RENUXPKG_CROSS_BASE}
Prefix=${RENUXPKG_CROSS_BASE}/usr
ArchData=${RENUXPKG_CROSS_BASE}/usr/lib/qt5
Data=${RENUXPKG_CROSS_BASE}/usr/share/qt5
Documentation=${RENUXPKG_CROSS_BASE}/usr/share/doc/qt5
Headers=${RENUXPKG_CROSS_BASE}/usr/include/qt5
Libraries=${RENUXPKG_CROSS_BASE}/usr/lib
LibraryExecutables=/usr/lib/qt5/libexec
Binaries=/usr/lib/qt5/bin
Tests=${RENUXPKG_CROSS_BASE}/usr/tests
Plugins=/usr/lib/qt5/plugins
Imports=${RENUXPKG_CROSS_BASE}/usr/lib/qt5/imports
Qml2Imports=${RENUXPKG_CROSS_BASE}/usr/lib/qt5/qml
Translations=${RENUXPKG_CROSS_BASE}/usr/share/qt5/translations
Settings=${RENUXPKG_CROSS_BASE}/etc/xdg
Examples=${RENUXPKG_CROSS_BASE}/usr/share/qt5/examples
HostPrefix=/usr
HostData=/usr/lib/qt5
HostBinaries=/usr/lib/qt5/bin
HostLibraries=/usr/lib
Spec=linux-g++
TargetSpec=$RENUXPKG_WRAPPERDIR/qt5/target-spec/linux-g++
_EOF

	# create the qmake-wrapper here because it only
	# makes sense together with the qmake build-helper
	# and not to interfere with e.g. the qmake build-style
	#
	#   + base flags will be picked up from QMAKE_{C,CXX,LD}FLAGS
	#   + hardening flags will be picked up from environment variables
        cat > "${RENUXPKG_WRAPPERDIR}/qmake5" <<_EOF
#!/bin/sh
exec /usr/lib/qt5/bin/qmake "\$@" -qtconf "${RENUXPKG_WRAPPERDIR}/qt5.conf" \\
	QMAKE_CFLAGS+="\${CFLAGS}" \\
	QMAKE_CXXFLAGS+="\${CXXFLAGS}" \\
	QMAKE_LFLAGS+="\${LDFLAGS}"
_EOF
else
        cat > "${RENUXPKG_WRAPPERDIR}/qmake5" <<_EOF
#!/bin/sh
exec /usr/lib/qt5/bin/qmake \
	"\$@" \
	PREFIX=/usr \
	QT_INSTALL_PREFIX=/usr \
	LIB=/usr/lib \
	QMAKE_CC="$CC" QMAKE_CXX="$CXX" \
	QMAKE_LINK="$CXX" QMAKE_LINK_C="$CC" \
	QMAKE_CFLAGS+="\${CFLAGS}" \
	QMAKE_CXXFLAGS+="\${CXXFLAGS}" \
	QMAKE_LFLAGS+="\${LDFLAGS}" \
	CONFIG+=no_qt_rpath
_EOF
fi
chmod 755 ${RENUXPKG_WRAPPERDIR}/qmake5
cp -p ${RENUXPKG_WRAPPERDIR}/qmake{5,-qt5}
if [ -z "$qmake_default_version" ] || [ "${qmake_default_version}" = "5" ]; then
	cp -p ${RENUXPKG_WRAPPERDIR}/qmake{5,}
fi
