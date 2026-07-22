---
name: build-fork
description: Build the shiroikuma-yosuga (白い熊 縁, Memento fork) GNU/Linux amd64 .deb release into ~/tmp/ with one command. Use whenever 白い熊 asks to build the app, build the deb, make a release build, or after ANY functional change.
---

# Build the release .deb

This is **shiroikuma-yosuga** — 白い熊's fork of [Memento](https://github.com/ripose-jp/Memento)
(C++ / Qt 6 / mpv video player for studying Japanese). We build **only** the GNU/Linux amd64
`.deb` for Tuxedo OS — no APK, no other targets.

> **ALWAYS build after any functional change — no asking** (standing authorization from
> 白い熊). The `.deb` lands in `~/tmp/` — this machine IS the target (Tuxedo OS), so there is
> no adb/scp delivery; just announce loudly what was built and where. Building does NOT
> commit or push; that still waits for 白い熊's explicit "Push".

## The one command

```bash
_scripts/build-fork.sh
```

It: configures + compiles (CMake/Ninja, Release, `MEMENTO_RELEASE_BUILD=ON`,
`MEMENTO_QAPPLICATION=ON`) → stages a DESTDIR install → computes runtime `Depends` via
`dpkg-shlibdeps` → packages with `dpkg-deb` → **bumps `BUILD_NUMBER`** in `fork.properties`.

Output (`<ver>` = `<upstream CMakeLists.txt VERSION>+<BUILD_NUMBER>`, e.g. `2.0.2+1`):
- `~/tmp/shiroikuma-yosuga_<ver>_amd64.deb`

## Toolchain (all system packages, already installed)

- Qt 6.9.2 (`qt6-base-dev`, `qt6-svg-dev`), `libmpv-dev` 0.41, `libjson-c-dev`, `libzip-dev`,
  `libsqlite3-dev`, `cmake`, `ninja-build`, `dpkg-dev` (for `dpkg-shlibdeps`).
- **qcoro** is NOT a system package — the build vendors it via CMake `FetchContent`
  (`extern/CMakeLists.txt`), so the **first configure needs network** (and re-fetches after
  `build/` is cleaned).
- `MEMENTO_MECAB_SUPPORT` is OFF (`libmecab-dev` not installed on this host). If 白い熊 wants
  MeCab deconjugation, install `libmecab-dev mecab-ipadic-utf8` first, then add
  `-DMEMENTO_MECAB_SUPPORT=ON` to the script and `mecab, mecab-ipadic-utf8` to Recommends.

## Notes / invariants

- Every build MUST go through `_scripts/build-fork.sh` so `BUILD_NUMBER` bumps — never reuse
  a `+N`, never overwrite an older deb in `~/tmp/`.
- The build directory is `build/fork/` (gitignored via upstream's `/build*/` rule).
- Install with `sudo apt install ~/tmp/shiroikuma-yosuga_<ver>_amd64.deb` (resolves the
  Depends), or `sudo dpkg -i` if deps are already present.
- Never commit/push on your own. No Claude attribution in commits (see `CLAUDE.md`).
