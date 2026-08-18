# Renux binary package repository

Binary packages for the Renux distribution (FreeBSD 15.1 based), built with rpkg.

## Repository layout

- `current/` — packages for `amd64`, served at
  `https://renuxproject.github.io/renux-packages/current/`
- `renux-key.pub` — RSA public key used to sign the repository
- `keys/` — the same key in rpkg `.plist` format, ready to drop into
  `/var/db/renuxpkg/keys/`

## Usage

Add the repository to `/usr/local/etc/renuxpkg.d/repos-remote.conf`:

```
repository=https://renuxproject.github.io/renux-packages/current
```

Install:

```
rpkg-install -S nano
```

On first sync rpkg will ask to import the repository public key
(fingerprint `ba:4e:5a:b8:98:c1:09:3e:b7:70:2b:36:ba:48:68:27`).
To skip the prompt, install the key manually:

```
mkdir -p /var/db/renuxpkg/keys
cp keys/ba:4e:5a:b8:98:c1:09:3e:b7:70:2b:36:ba:48:68:27.plist /var/db/renuxpkg/keys/
```

## Building

Packages are cross-compiled from source on a Linux host with `zig cc`
targeting `x86_64-freebsd`, using a sysroot extracted from the FreeBSD
15.1-RELEASE `base.txz`. See the `renux-packages` repository for the
`rpkg-src` build framework.