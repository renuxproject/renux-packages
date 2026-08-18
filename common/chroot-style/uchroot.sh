#!/bin/sh
#
# This chroot script uses rpkg-uchroot(1).
#
readonly MASTERDIR="$1"
readonly DISTDIR="$2"
readonly HOSTDIR="$3"
readonly EXTRA_ARGS="$4"
readonly CMD="$5"
shift 5

msg_red() {
	# error messages in bold/red
	[ -n "$NOCOLORS" ] || printf >&2 "\033[1m\033[31m"
	printf "=> ERROR: %s\\n" "$@" >&2
	[ -n "$NOCOLORS" ] || printf >&2 "\033[m"
}

readonly RENUXPKG_UCHROOT_CMD="$(command -v rpkg-uchroot 2>/dev/null)"

if [ -z "$RENUXPKG_UCHROOT_CMD" ]; then
	msg_red "could not find rpkg-uchroot"
	exit 1
fi

if ! [ -x "$RENUXPKG_UCHROOT_CMD" ]; then
	msg_red "rpkg-uchroot is not executable. Are you in the $(stat -c %G "$RENUXPKG_UCHROOT_CMD") group?"
	exit 1
fi

if [ -z "$MASTERDIR" ] || [ -z "$DISTDIR" ]; then
	msg_red "$0: MASTERDIR/DISTDIR not set"
	exit 1
fi

exec rpkg-uchroot ${RENUXPKG_TEMP_MASTERDIR:+-O} $EXTRA_ARGS -b $DISTDIR:/renux-packages ${HOSTDIR:+-b $HOSTDIR:/host} -- $MASTERDIR $CMD "$@"
