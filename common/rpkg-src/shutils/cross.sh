# vim: set ts=4 sw=4 et:

remove_pkg_cross_deps() {
    local rval= tmplogf= prevs=0
    [ -z "$RENUXPKG_CROSS_BUILD" ] && return 0

    cd $RENUXPKG_MASTERDIR || return 1
    msg_normal "${pkgver:-rpkg-src}: removing autocrossdeps, please wait...\n"
    tmplogf=$(mktemp) || exit 1

    if [ -z "$RENUXPKG_REMOVE_XCMD" ]; then
        source_file $RENUXPKG_CROSSPFDIR/${RENUXPKG_CROSS_BUILD}.sh
        RENUXPKG_REMOVE_XCMD="env RENUXPKG_TARGET_ARCH=$RENUXPKG_TARGET_MACHINE rpkg-remove -r /usr/$RENUXPKG_CROSS_TRIPLET"
    fi

    $RENUXPKG_REMOVE_XCMD -Ryo > $tmplogf 2>&1
    rval=$?
    while [ $rval -eq 0 ]; do
        local curs=$(stat_size $tmplogf)
        if [ $curs -eq $prevs ]; then
            break
        fi
        prevs=$curs
        $RENUXPKG_REMOVE_XCMD -Ryo >> $tmplogf 2>&1
        rval=$?
    done

    if [ $rval -ne 0 ]; then
        msg_red "${pkgver:-rpkg-src}: failed to remove autocrossdeps:\n"
        cat $tmplogf && rm -f $tmplogf
        msg_error "${pkgver:-rpkg-src}: cannot continue!\n"
    fi
    rm -f $tmplogf
}

prepare_cross_sysroot() {
    local cross="$1"
    local statefile="$RENUXPKG_MASTERDIR/.rpkg-${cross}-done"

    [ -z "$cross" -o "$cross" = "" -o -f $statefile ] && return 0

    # Check if the cross pkg is installed in host.
    check_installed_pkg cross-${RENUXPKG_CROSS_TRIPLET}-0.1_1
    [ $? -eq 0 ] && return 0

    # Check if the cross compiler pkg is available in repos, otherwise build it.
    pkg_available cross-${RENUXPKG_CROSS_TRIPLET}
    rval=$?
    if [ $rval -eq 0 ]; then
        $RENUXPKG_LIBEXECDIR/build.sh cross-${RENUXPKG_CROSS_TRIPLET} cross-${RENUXPKG_CROSS_TRIPLET} pkg || return $?
    fi

    # Check if cross-vpkg-dummy is installed.
    check_installed_pkg cross-vpkg-dummy-0.30_1 $cross
    [ $? -eq 0 ] && return 0

    # Check for cross-vpkg-dummy available for the target arch, otherwise build it.
    pkg_available 'cross-vpkg-dummy>=0.34_1' $cross
    if [ $? -eq 0 ]; then
        $RENUXPKG_LIBEXECDIR/build.sh cross-vpkg-dummy bootstrap pkg $cross init || return $?
    fi

    msg_normal "Installing $cross cross pkg: cross-vpkg-dummy ...\n"
    errlog=$(mktemp) || exit 1
    $RENUXPKG_INSTALL_XCMD -Syfd cross-vpkg-dummy &>$errlog
    rval=$?
    if [ $rval -ne 0 ]; then
        msg_red "failed to install cross-vpkg-dummy (error $rval)\n"
        cat $errlog
        rm -f $errlog
        msg_error "cannot continue due to errors above\n"
    fi
    rm -f $errlog
    # Create top level symlinks in sysroot.
    RENUXPKG_ARCH=$RENUXPKG_TARGET_MACHINE rpkg-reconfigure -r $RENUXPKG_CROSS_BASE -f base-files &>/dev/null
    # Create a sysroot/include and sysroot/lib symlink just in case.
    ln -s usr/include ${RENUXPKG_CROSS_BASE}/include
    ln -s usr/lib ${RENUXPKG_CROSS_BASE}/lib

    touch -f $statefile

    return 0
}

install_cross_pkg() {
    local cross="$1" rval errlog

    [ -z "$cross" -o "$cross" = "" ] && return 0

    # Check if installed.
    check_installed_pkg cross-${RENUXPKG_CROSS_TRIPLET}-0.1_1
    [ $? -eq 0 ] && return 0

    # Check if the cross compiler pkg is available in repos, otherwise build it.
    pkg_available cross-${RENUXPKG_CROSS_TRIPLET}
    rval=$?
    if [ $rval -eq 0 ]; then
        $RENUXPKG_LIBEXECDIR/build.sh cross-${RENUXPKG_CROSS_TRIPLET} cross-${RENUXPKG_CROSS_TRIPLET} pkg || return $?
    fi

    errlog=$(mktemp) || exit 1
    msg_normal "rpkg-src: installing cross compiler: cross-${RENUXPKG_CROSS_TRIPLET} ...\n"
    $RENUXPKG_INSTALL_CMD -Syfd cross-${RENUXPKG_CROSS_TRIPLET} &>$errlog
    rval=$?
    if [ $rval -ne 0 -a $rval -ne 17 ]; then
        msg_red "failed to install cross-${RENUXPKG_CROSS_TRIPLET} (error $rval)\n"
        cat $errlog
        rm -f $errlog
        msg_error "cannot continue due to errors above\n"
    fi
    rm -f $errlog

    return 0
}

remove_cross_pkg() {
    local cross="$1" rval

    [ -z "$cross" -o "$cross" = "" ] && return 0

    source_file ${RENUXPKG_CROSSPFDIR}/${cross}.sh

    if [ -z "$CHROOT_READY" ]; then
        echo "ERROR: chroot mode not activated (install a bootstrap)."
        exit 1
    elif [ -z "$IN_CHROOT" ]; then
        return 0
    fi

    msg_normal "Removing cross pkg: cross-${RENUXPKG_CROSS_TRIPLET} ...\n"
    $RENUXPKG_REMOVE_CMD -Ry cross-${RENUXPKG_CROSS_TRIPLET} &>/dev/null
    rval=$?
    if [ $rval -ne 0 ]; then
        msg_error "failed to remove cross-${RENUXPKG_CROSS_TRIPLET} (error $rval)\n"
    fi
}
