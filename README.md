# renux-packages

Source packages for the Renux distribution (FreeBSD 15.1 based). Templates in
`srcpkgs/` are cross-compiled with `zig cc` targeting `x86_64-freebsd`, packaged
with rpkg, and published as a binary repository served from GitHub Pages at
`https://renuxproject.github.io/renux-packages/current/`.

## Repository layout

- `srcpkgs/<pkg>/template` — package templates (build instructions). Only `nano`
  exists for now; add more as `srcpkgs/<name>/template`.
- `common/scripts/build-renux-pkg.sh` — the cross-compile build script. This is
  the working build path used locally and by CI.
- `common/rpkg-src/`, `rpkg-src` — the rpkg-src build framework (a fork of
  void-packages/xbps-src). Not yet usable on FreeBSD: it needs a bootstrap
  (base-chroot/base-files templates) and a FreeBSD chroot, which are future work.
- `etc/renuxpkg.d/` — client configuration, including `repos-remote.conf`.
- `.github/workflows/build.yml` — CI that builds every template in `srcpkgs/`
  and publishes the resulting `.rpkg` files to the `gh-pages` branch.

## Building packages locally

Requirements: `zig` (0.16.x), the rpkg tools in `PATH` (`rpkg-create`,
`rpkg-rindex`, built from the `renux`/`renuxpkg` repository), `curl`, `tar`,
`make`, and a FreeBSD 15.1 sysroot extracted from `base.txz`:

```
mkdir -p sysroot
curl -fL -o base.txz https://download.freebsd.org/releases/amd64/15.1-RELEASE/base.txz
tar -xJf base.txz -C sysroot ./usr ./lib ./libexec
```

Build a package:

```
RENUX_SYSROOT="$PWD/sysroot" RENUXPKG_ARCH=amd64 \
  ./common/scripts/build-renux-pkg.sh nano hostdir/binpkgs/amd64
```

This produces `hostdir/binpkgs/amd64/nano-9.2_1.amd64.rpkg`. `hostdir/` and
`sysroot/` are gitignored.

## Continuous integration

`build.yml` runs on every change to `srcpkgs/` (or `workflow_dispatch`) and:

1. installs zig, builds the rpkg tools from source, and fetches the FreeBSD
   sysroot (cached);
2. builds every template in `srcpkgs/` into `repo/current/`;
3. indexes with `rpkg-rindex -a`;
4. signs the repository with the RSA key stored in the GitHub secret
   `RENUXPKG_PRIVKEY` (PEM private key; the corresponding public key must be
   `renux-key.pub`/`keys/` on the `gh-pages` branch);
5. updates the `gh-pages` branch, which GitHub Pages serves at
   `https://renuxproject.github.io/renux-packages/current/`.

Until `RENUXPKG_PRIVKEY` is set, CI publishes an unsigned repository (works with
`rpkg-install -r`, but a remote `rpkg-install -S` will reject it).

## Installing on Renux

Configure the remote repository (`/usr/local/etc/renuxpkg.d/repos-remote.conf`):

```
repository=https://renuxproject.github.io/renux-packages/current
```

Sync and install:

```
rpkg-install -S nano
```

On first sync rpkg prompts to import the repository public key
(fingerprint `ba:4e:5a:b8:98:c1:09:3e:b7:70:2b:36:ba:48:68:27`). To install the
key non-interactively, drop `keys/<fingerprint>.plist` from the `gh-pages`
branch into `/var/db/renuxpkg/keys/`.

## Adding a package

1. Create `srcpkgs/<name>/template` modeled on `srcpkgs/nano/template`
   (`pkgname`, `version`, `revision`, `build_style`, `configure_args`,
   `short_desc`, `maintainer`, `license`, `homepage`, `distfiles`, `checksum`).
2. Build it locally with `common/scripts/build-renux-pkg.sh`.
3. Commit and push — CI builds and publishes it automatically.

See `Manual.md` for the template variables understood by the rpkg-src framework
and `CONTRIBUTING.md` for contribution guidelines.