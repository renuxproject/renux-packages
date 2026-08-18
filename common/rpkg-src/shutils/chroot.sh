# vim: set ts=4 sw=4 et:

install_base_chroot() {
    local _bootstrap_arch _target_arch="$1"
    [ "$CHROOT_READY" ] && return
    if [ "$_target_arch" = "bootstrap" ]; then
        _target_arch=""
        unset RENUXPKG_INSTALL_ARGS
    fi
    # binary bootstrap
    msg_normal "rpkg-src: installing base-chroot...\n"
    if [ -n "$_target_arch" ]; then
        _bootstrap_arch="env RENUXPKG_TARGET_ARCH=$_target_arch"
    fi
    (export RENUXPKG_MACHINE="$_target_arch" RENUXPKG_ARCH="$_target_arch"; chroot_sync_repodata)
    ${_bootstrap_arch} $RENUXPKG_INSTALL_CMD ${RENUXPKG_INSTALL_ARGS} -y base-chroot
    if [ $? -ne 0 ]; then
        msg_error "rpkg-src: failed to install base-chroot!\n"
    fi
    # Reconfigure base-files to create dirs/symlinks.
    if rpkg-query -r $RENUXPKG_MASTERDIR base-files &>/dev/null; then
        RENUXPKG_ARCH="$_target_arch" rpkg-reconfigure -r $RENUXPKG_MASTERDIR -f base-files &>/dev/null
    fi

    msg_normal "rpkg-src: installed base-chroot successfully!\n"
    chroot_prepare "$_target_arch" || msg_error "rpkg-src: failed to initialize chroot!\n"
    chroot_check
    chroot_handler clean
}

reconfigure_base_chroot() {
    local statefile="$RENUXPKG_MASTERDIR/.rpkg_chroot_configured"
    local pkgs="glibc-locales ca-certificates"
    [ -z "$IN_CHROOT" -o -e $statefile ] && return 0
    # Reconfigure ca-certificates.
    msg_normal "rpkg-src: reconfiguring base-chroot...\n"
    for f in ${pkgs}; do
        if rpkg-query -r $RENUXPKG_MASTERDIR $f &>/dev/null; then
            rpkg-reconfigure -r $RENUXPKG_MASTERDIR -f $f
        fi
    done
    touch -f $statefile
}

update_base_chroot() {
    local keep_all_force=$1
    [ -z "$CHROOT_READY" ] && return
    msg_normal "rpkg-src: updating software in $RENUXPKG_MASTERDIR masterdir...\n"
    # no need to sync repodata, chroot_sync_repodata() does it for us.
    if $(${RENUXPKG_INSTALL_CMD} ${RENUXPKG_INSTALL_ARGS} -nu|grep -q renuxpkg); then
        ${RENUXPKG_INSTALL_CMD} ${RENUXPKG_INSTALL_ARGS} -yu renuxpkg || msg_error "rpkg-src: failed to update renuxpkg!\n"
    fi
    ${RENUXPKG_INSTALL_CMD} ${RENUXPKG_INSTALL_ARGS} -yu || msg_error "rpkg-src: failed to update base-chroot!\n"
    msg_normal "rpkg-src: cleaning up $RENUXPKG_MASTERDIR masterdir...\n"
    [ -z "$RENUXPKG_KEEP_ALL" -a -z "$RENUXPKG_SKIP_DEPS" ] && remove_pkg_autodeps
    [ -z "$RENUXPKG_KEEP_ALL" -a -z "$keep_all_force" ] && rm -rf $RENUXPKG_MASTERDIR/builddir $RENUXPKG_MASTERDIR/destdir
}

# FIXME: $RENUXPKG_FFLAGS is not set when chroot_init() is run
# It is set in common/build-profiles/bootstrap.sh but lost somewhere?
chroot_init() {
    mkdir -p $RENUXPKG_MASTERDIR/usr/local/etc/renuxpkg.d

    : ${RENUXPKG_CONFIG_FILE:=/dev/null}
    cat > $RENUXPKG_MASTERDIR/usr/local/etc/renuxpkg.d/rpkg-src.conf <<_EOF
# Generated configuration file by rpkg-src, DO NOT EDIT!
$(grep -E '^RENUXPKG_.*' "$RENUXPKG_CONFIG_FILE")
RENUXPKG_MASTERDIR=/
RENUXPKG_CFLAGS="$RENUXPKG_CFLAGS"
RENUXPKG_CXXFLAGS="$RENUXPKG_CXXFLAGS"
RENUXPKG_FFLAGS="$RENUXPKG_FFLAGS"
RENUXPKG_CPPFLAGS="$RENUXPKG_CPPFLAGS"
RENUXPKG_LDFLAGS="$RENUXPKG_LDFLAGS"
RENUXPKG_HOSTDIR=/host
# End of configuration file.
_EOF

    # Create custom script to start the chroot bash shell.
    cat > $RENUXPKG_MASTERDIR/bin/rpkg-shell <<_EOF
#!/bin/sh

RENUXPKG_SRC_VERSION="$RENUXPKG_SRC_VERSION"

. /usr/local/etc/renuxpkg.d/rpkg-src.conf

PATH=/renux-packages:/usr/bin

exec env -i -- SHELL=/bin/sh PATH="\$PATH" DISTCC_HOSTS="\$RENUXPKG_DISTCC_HOSTS" DISTCC_DIR="/host/distcc" \
    ${RENUXPKG_ARCH+RENUXPKG_ARCH=$RENUXPKG_ARCH} ${RENUXPKG_CHECK_PKGS+RENUXPKG_CHECK_PKGS=$RENUXPKG_CHECK_PKGS} \
    CCACHE_DIR="/host/ccache" IN_CHROOT=1 LC_COLLATE=C LANG=en_US.UTF-8 TERM=linux HOME="/tmp" \
    PS1="[\u@$RENUXPKG_MASTERDIR \W]$ " /bin/bash +h "\$@"
_EOF

    chmod 755 $RENUXPKG_MASTERDIR/bin/rpkg-shell
    cp -f /etc/resolv.conf $RENUXPKG_MASTERDIR/etc
    return 0
}

chroot_prepare() {
    local f=

    if [ -f $RENUXPKG_MASTERDIR/.rpkg_chroot_init ]; then
        return 0
    elif [ ! -f $RENUXPKG_MASTERDIR/bin/bash ]; then
        msg_error "Bootstrap not installed in $RENUXPKG_MASTERDIR, can't continue.\n"
    fi

    # Some software expects /etc/localtime to be a symbolic link it can read to
    # determine the name of the time zone, so set up the expected link
    # structure.
    ln -sf ../usr/share/zoneinfo/UTC $RENUXPKG_MASTERDIR/etc/localtime

    for f in dev sys tmp proc host boot; do
        [ ! -d $RENUXPKG_MASTERDIR/$f ] && mkdir -p $RENUXPKG_MASTERDIR/$f
    done

    # Copy /etc/passwd and /etc/group from base-files.
    cp -f $RENUXPKG_SRCPKGDIR/base-files/files/passwd $RENUXPKG_MASTERDIR/etc
    echo "$(whoami):x:$(id -u):$(id -g):$(whoami) user:/tmp:/bin/rpkg-shell" \
        >> $RENUXPKG_MASTERDIR/etc/passwd
    cp -f $RENUXPKG_SRCPKGDIR/base-files/files/group $RENUXPKG_MASTERDIR/etc
    echo "$(whoami):x:$(id -g):" >> $RENUXPKG_MASTERDIR/etc/group

    # Copy /etc/hosts from base-files.
    cp -f $RENUXPKG_SRCPKGDIR/base-files/files/hosts $RENUXPKG_MASTERDIR/etc

    # Prepare default locale: en_US.UTF-8.
    if [ -s ${RENUXPKG_MASTERDIR}/etc/default/libc-locales ]; then
        printf '%s\n' \
            'C.UTF-8 UTF-8' \
            'en_US.UTF-8 UTF-8' \
            >> ${RENUXPKG_MASTERDIR}/etc/default/libc-locales
    fi

    touch -f $RENUXPKG_MASTERDIR/.rpkg_chroot_init
    [ -n "$1" ] && echo $1 >> $RENUXPKG_MASTERDIR/.rpkg_chroot_init

    return 0
}

chroot_handler() {
    local action="$1" pkg="$2" rv=0 arg= _envargs=

    [ -z "$action" -a -z "$pkg" ] && return 1

    if [ -n "$IN_CHROOT" -o -z "$CHROOT_READY" ]; then
        return 0
    fi
    if [ ! -d $RENUXPKG_MASTERDIR/renux-packages ]; then
        mkdir -p $RENUXPKG_MASTERDIR/renux-packages
    fi

    case "$action" in
        fetch|extract|patch|configure|build|check|install|pkg|bootstrap-update|chroot|clean|clean-repocache)
            chroot_prepare || return $?
            chroot_init || return $?
            ;;
    esac

    if [ "$action" = "chroot" ]; then
        $RENUXPKG_COMMONDIR/chroot-style/${RENUXPKG_CHROOT_CMD:=uunshare}.sh \
            $RENUXPKG_MASTERDIR $RENUXPKG_DISTDIR "$RENUXPKG_HOSTDIR" "$RENUXPKG_CHROOT_CMD_ARGS" /bin/rpkg-shell
        rv=$?
    else
        env -i -- PATH="/usr/bin:$PATH" SHELL=/bin/sh \
            HOME=/tmp IN_CHROOT=1 LC_COLLATE=C LANG=en_US.UTF-8 \
            ${http_proxy:+http_proxy="${http_proxy}"} \
            ${https_proxy:+https_proxy="${https_proxy}"} \
            ${ftp_proxy:+ftp_proxy="${ftp_proxy}"} \
            ${all_proxy:+all_proxy="${all_proxy}"} \
            ${no_proxy:+no_proxy="${no_proxy}"} \
            ${HTTP_PROXY:+HTTP_PROXY="${HTTP_PROXY}"} \
            ${HTTPS_PROXY:+HTTPS_PROXY="${HTTPS_PROXY}"} \
            ${FTP_PROXY:+FTP_PROXY="${FTP_PROXY}"} \
            ${SOCKS_PROXY:+SOCKS_PROXY="${SOCKS_PROXY}"} \
            ${NO_PROXY:+NO_PROXY="${NO_PROXY}"} \
            ${HTTP_PROXY_AUTH:+HTTP_PROXY_AUTH="${HTTP_PROXY_AUTH}"} \
            ${FTP_RETRIES:+FTP_RETRIES="${FTP_RETRIES}"} \
            SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
            RENUXPKG_GIT_REVS="$RENUXPKG_GIT_REVS" \
            RENUXPKG_ALLOW_CHROOT_BREAKOUT="$RENUXPKG_ALLOW_CHROOT_BREAKOUT" \
            RENUXPKG_TEMP_MASTERDIR="$RENUXPKG_TEMP_MASTERDIR" \
            ${RENUXPKG_ALT_REPOSITORY:+RENUXPKG_ALT_REPOSITORY=$RENUXPKG_ALT_REPOSITORY} \
            $RENUXPKG_COMMONDIR/chroot-style/${RENUXPKG_CHROOT_CMD:=uunshare}.sh \
            $RENUXPKG_MASTERDIR $RENUXPKG_DISTDIR "$RENUXPKG_HOSTDIR" "$RENUXPKG_CHROOT_CMD_ARGS" \
            /renux-packages/rpkg-src $RENUXPKG_OPTIONS $action $pkg
        rv=$?
    fi

    return $rv
}

chroot_sync_repodata() {
    local f= hostdir= confdir= crossconfdir=

    # always start with an empty renuxpkg.d
    confdir=$RENUXPKG_MASTERDIR/etc/renuxpkg.d
    crossconfdir=$RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/etc/renuxpkg.d

    [ -d $confdir ] && rm -rf $confdir
    [ -d $crossconfdir ] && rm -rf $crossconfdir

    if [ -d $RENUXPKG_DISTDIR/etc/renuxpkg.d/custom ]; then
        mkdir -p $confdir $crossconfdir
        cp -f $RENUXPKG_DISTDIR/etc/renuxpkg.d/custom/*.conf $confdir
        cp -f $RENUXPKG_DISTDIR/etc/renuxpkg.d/custom/*.conf $crossconfdir
    fi
    if [ "$CHROOT_READY" ]; then
        hostdir=/host
    else
        hostdir=$RENUXPKG_HOSTDIR
    fi

    # Update renuxpkg alternative repository if set.
    mkdir -p $confdir
    if [ -n "$RENUXPKG_ALT_REPOSITORY" ]; then
        cat <<- ! > $confdir/00-repository-alt-local.conf
		repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/bootstrap
		repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}
		repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/nonfree
		repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/debug
		!
        if [ "$RENUXPKG_MACHINE" = "x86_64" ]; then
            cat <<- ! >> $confdir/00-repository-alt-local.conf
			repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/multilib/bootstrap
			repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/multilib
			repository=$hostdir/binpkgs/${RENUXPKG_ALT_REPOSITORY}/multilib/nonfree
			!
        fi
    else
        rm -f $confdir/00-repository-alt-local.conf
    fi

    # Disable 00-repository-main.conf from share/renuxpkg.d (part of renuxpkg)
    ln -s /dev/null $confdir/00-repository-main.conf

    # Generate renuxpkg.d(5) configuration files for repositories
    sed -e "s,/host,$hostdir,g" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-local.conf \
        > $confdir/10-repository-local.conf

    # Install multilib conf for local repos if it exists for the architecture
    if [ -s "${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-local-${RENUXPKG_MACHINE}-multilib.conf" ]; then
        install -Dm644 ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-local-${RENUXPKG_MACHINE}-multilib.conf \
            $confdir/12-repository-local-multilib.conf
    fi

    # mirror_sed is a sed script: nop by default
    local mirror_sed
    if [ -n "$RENUXPKG_MIRROR" ]; then
        # when RENUXPKG_MIRROR is set, mirror_sed rewrites remote repos
        mirror_sed="s|^repository=http.*/current|repository=${RENUXPKG_MIRROR}|"
    fi

    if [ "$RENUXPKG_SKIP_REMOTEREPOS" ]; then
        rm -f $confdir/*remote*
    else
        if [ -s "${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_MACHINE}.conf" ]; then
            # If per-architecture base remote repo config exists, use that
            sed -e "$mirror_sed" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_MACHINE}.conf \
                > $confdir/20-repository-remote.conf
        else
            # Otherwise use generic base for musl or glibc
            local suffix=
            case "$RENUXPKG_MACHINE" in
                *-musl) suffix="-musl";;
            esac
            sed -e "$mirror_sed" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote${suffix}.conf \
                > $confdir/20-repository-remote.conf
        fi
        # Install multilib conf for remote repos if it exists for the architecture
        if [ -s "${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_MACHINE}-multilib.conf" ]; then
            sed -e "$mirror_sed" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_MACHINE}-multilib.conf \
                > $confdir/22-repository-remote-multilib.conf
        fi
    fi

    echo "syslog=false" > $confdir/00-rpkg-src.conf
    echo "staging=true" >> $confdir/00-rpkg-src.conf

    # Copy host repos to the cross root.
    if [ -n "$RENUXPKG_CROSS_BUILD" ]; then
        rm -rf $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/etc/renuxpkg.d
        mkdir -p $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/etc/renuxpkg.d
        # Disable 00-repository-main.conf from share/renuxpkg.d (part of renuxpkg)
        ln -s /dev/null $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/etc/renuxpkg.d/00-repository-main.conf
        # copy renuxpkg.d files from host for local repos
        cp ${RENUXPKG_MASTERDIR}/etc/renuxpkg.d/*local*.conf \
            $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/etc/renuxpkg.d
        if [ "$RENUXPKG_SKIP_REMOTEREPOS" ]; then
            rm -f $crossconfdir/*remote*
        else
            # Same general logic as above, just into cross root, and no multilib
            if [ -s "${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_TARGET_MACHINE}.conf" ]; then
                sed -e "$mirror_sed" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote-${RENUXPKG_TARGET_MACHINE}.conf \
                    > $crossconfdir/20-repository-remote.conf
            else
                local suffix=
                case "$RENUXPKG_TARGET_MACHINE" in
                    *-musl) suffix="-musl"
                esac
                sed -e "$mirror_sed" ${RENUXPKG_DISTDIR}/etc/renuxpkg.d/repos-remote${suffix}.conf \
                    > $crossconfdir/20-repository-remote.conf
            fi
        fi

        echo "syslog=false" > $crossconfdir/00-rpkg-src.conf
        echo "staging=true" >> $crossconfdir/00-rpkg-src.conf
    fi


    # Copy renuxpkg repository keys to the masterdir.
    mkdir -p $RENUXPKG_MASTERDIR/var/db/renuxpkg/keys
    cp -f $RENUXPKG_COMMONDIR/repo-keys/*.plist $RENUXPKG_MASTERDIR/var/db/renuxpkg/keys
    if [ -n "$(shopt -s nullglob; echo "$RENUXPKG_DISTDIR"/etc/repo-keys/*.plist)" ]; then
        cp -f "$RENUXPKG_DISTDIR"/etc/repo-keys/*.plist "$RENUXPKG_MASTERDIR"/var/db/renuxpkg/keys
    fi

    # Make sure to sync index for remote repositories.
    if [ -z "$RENUXPKG_SKIP_REMOTEREPOS" -a -z "$RENUXPKG_SKIP_SYNC" ]; then
        msg_normal "rpkg-src: updating repositories for host ($RENUXPKG_MACHINE)...\n"
        $RENUXPKG_INSTALL_CMD $RENUXPKG_INSTALL_ARGS -S
    fi

    if [ -n "$RENUXPKG_CROSS_BUILD" ]; then
        # Copy host keys to the target rootdir.
        mkdir -p $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/var/db/renuxpkg/keys
        cp $RENUXPKG_MASTERDIR/var/db/renuxpkg/keys/*.plist \
            $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE/var/db/renuxpkg/keys
        # Make sure to sync index for remote repositories.
        if [ -z "$RENUXPKG_SKIP_REMOTEREPOS" -a -z "$RENUXPKG_SKIP_SYNC" ]; then
            msg_normal "rpkg-src: updating repositories for target ($RENUXPKG_TARGET_MACHINE)...\n"
            env -- RENUXPKG_TARGET_ARCH=$RENUXPKG_TARGET_MACHINE \
                $RENUXPKG_INSTALL_CMD $RENUXPKG_INSTALL_ARGS -r $RENUXPKG_MASTERDIR/$RENUXPKG_CROSS_BASE -S
        fi
    fi

    return 0
}
