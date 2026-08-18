# This build-helper sets up qmake’s cross environment
# in cases the build-style is mixed,
# e.g. when in a gnu-configure style the configure
# script calls qmake or a makefile in a gnu-makefile style,
# respectively.

if [ "$CROSS_BUILD" ]; then
	mkdir -p "${RENUXPKG_WRAPPERDIR}/qt6/target-spec/linux-g++"
	cat > "${RENUXPKG_WRAPPERDIR}/qt6/target-spec/linux-g++/qmake.conf" <<_EOF
MAKEFILE_GENERATOR      = UNIX
CONFIG                 += incremental no_qt_rpath
QMAKE_INCREMENTAL_STYLE = sublib

include(/usr/lib/qt6/mkspecs/common/linux.conf)
include(/usr/lib/qt6/mkspecs/common/gcc-base-unix.conf)
include(/usr/lib/qt6/mkspecs/common/g++-unix.conf)

QMAKE_TARGET_CONFIG     = ${RENUXPKG_CROSS_BASE}/usr/lib/qt6/mkspecs/qconfig.pri
QMAKE_TARGET_MODULE     = ${RENUXPKG_CROSS_BASE}/usr/lib/qt6/mkspecs/qmodule.pri
QMAKEMODULES            = ${RENUXPKG_CROSS_BASE}/usr/lib/qt6/mkspecs/modules
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
	echo "#include \"${RENUXPKG_CROSS_BASE}/usr/lib/qt6/mkspecs/linux-g++/qplatformdefs.h\"" > "${RENUXPKG_WRAPPERDIR}/qt6/target-spec/linux-g++/qplatformdefs.h"

	cat > "${RENUXPKG_WRAPPERDIR}/qt6.conf" <<_EOF
[Paths]
Sysroot=${RENUXPKG_CROSS_BASE}
Prefix=${RENUXPKG_CROSS_BASE}/usr
ArchData=${RENUXPKG_CROSS_BASE}/usr/lib/qt6
Data=${RENUXPKG_CROSS_BASE}/usr/share/qt6
Documentation=${RENUXPKG_CROSS_BASE}/usr/share/doc/qt6
Headers=${RENUXPKG_CROSS_BASE}/usr/include/qt6
Libraries=${RENUXPKG_CROSS_BASE}/usr/lib
LibraryExecutables=/usr/lib/qt6/libexec
Binaries=/usr/lib/qt6/bin
Tests=${RENUXPKG_CROSS_BASE}/usr/tests
Plugins=/usr/lib/qt6/plugins
Imports=${RENUXPKG_CROSS_BASE}/usr/lib/qt6/imports
Qml2Imports=${RENUXPKG_CROSS_BASE}/usr/lib/qt6/qml
Translations=${RENUXPKG_CROSS_BASE}/usr/share/qt6/translations
Settings=${RENUXPKG_CROSS_BASE}/etc/xdg
Examples=${RENUXPKG_CROSS_BASE}/usr/lib/qt6/examples
HostPrefix=/usr
HostData=/usr/lib/qt6
HostBinaries=/usr/lib/qt6/bin
HostLibraries=/usr/lib
HostLibraryExecutables=/usr/lib/qt6/libexec
Spec=linux-g++
TargetSpec=$RENUXPKG_WRAPPERDIR/qt6/target-spec/linux-g++
_EOF

	# create the qmake-wrapper here because it only
	# makes sense together with the qmake build-helper
	# and not to interfere with e.g. the qmake build-style
	#
	#   + base flags will be picked up from QMAKE_{C,CXX,LD}FLAGS
	#   + hardening flags will be picked up from environment variables
        cat > "${RENUXPKG_WRAPPERDIR}/qmake6" <<_EOF
#!/bin/sh
exec /usr/lib/qt6/bin/qmake "\$@" -qtconf "${RENUXPKG_WRAPPERDIR}/qt6.conf" \\
	QMAKE_CFLAGS+="\${CFLAGS}" \\
	QMAKE_CXXFLAGS+="\${CXXFLAGS}" \\
	QMAKE_LFLAGS+="\${LDFLAGS}"
_EOF
	cat > "${RENUXPKG_WRAPPERDIR}/qtpaths6" <<-_EOF
	#!/bin/sh
	exec /usr/lib/qt6/bin/qtpaths6 "\$@" -qtconf "${RENUXPKG_WRAPPERDIR}/qt6.conf"
	_EOF
	chmod +x "${RENUXPKG_WRAPPERDIR}/qtpaths6"
	cp -p ${RENUXPKG_WRAPPERDIR}/qtpaths{6,-qt6}
else
        cat > "${RENUXPKG_WRAPPERDIR}/qmake6" <<_EOF
#!/bin/sh
exec /usr/lib/qt6/bin/qmake \
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
	ln -sf /usr/lib/qt6/bin/qtpaths6 "$RENUXPKG_WRAPPERDIR/qtpaths6"
	ln -sf /usr/lib/qt6/bin/qtpaths6 "$RENUXPKG_WRAPPERDIR/qtpaths-qt6"
fi
chmod 755 ${RENUXPKG_WRAPPERDIR}/qmake6
cp -p ${RENUXPKG_WRAPPERDIR}/qmake{6,-qt6}
if [ -z "$qmake_default_version" ] || [ "${qmake_default_version}" = "6" ]; then
	cp -p ${RENUXPKG_WRAPPERDIR}/qmake{6,}
fi
