# fix building non-pure-python modules on cross
if [ -n "$CROSS_BUILD" ]; then
	export PYPREFIX="$RENUXPKG_CROSS_BASE"
	export CFLAGS+=" -I${RENUXPKG_CROSS_BASE}/${py3_inc} -I${RENUXPKG_CROSS_BASE}/usr/include"
	export CXXFLAGS+=" -I${RENUXPKG_CROSS_BASE}/${py3_inc} -I${RENUXPKG_CROSS_BASE}/usr/include"
	export LDFLAGS+=" -L${RENUXPKG_CROSS_BASE}/${py3_lib} -L${RENUXPKG_CROSS_BASE}/usr/lib"
	export CC="${RENUXPKG_CROSS_TRIPLET}-gcc -pthread $CFLAGS $LDFLAGS"
	export CXX="${RENUXPKG_CROSS_TRIPLET}-g++ -pthread $CXXFLAGS $LDFLAGS"
	export LDSHARED="${CC} -shared $LDFLAGS"
	export PYTHON_CONFIG="${RENUXPKG_CROSS_BASE}/usr/bin/python3-config"
	export PYTHONPATH="${RENUXPKG_CROSS_BASE}/${py3_lib}"
	for f in ${RENUXPKG_CROSS_BASE}/${py3_lib}/_sysconfigdata_*; do
		[ -f "$f" ] || continue
		f=${f##*/}
		_PYTHON_SYSCONFIGDATA_NAME=${f%.py}
	done
	[ -n "$_PYTHON_SYSCONFIGDATA_NAME" ] && export _PYTHON_SYSCONFIGDATA_NAME
fi
