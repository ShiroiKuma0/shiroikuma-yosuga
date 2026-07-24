#!/usr/bin/env bash
# Canonical fork build for shiroikuma-yosuga (白い熊 縁, Memento fork).
# Builds the GNU/Linux amd64 .deb into ~/tmp/ and bumps BUILD_NUMBER.
#
# Output: ~/tmp/shiroikuma-yosuga_<upstream CMake VERSION>+<BUILD_NUMBER>_amd64.deb
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

PKG=shiroikuma-yosuga
VER="$(sed -nE 's/^ *VERSION +([0-9.]+).*/\1/p' CMakeLists.txt | head -1)"
N="$(sed -nE 's/^BUILD_NUMBER=([0-9]+)$/\1/p' fork.properties)"
[[ -n "$VER" && -n "$N" ]] || { echo "ERROR: version or BUILD_NUMBER not found" >&2; exit 1; }
FORKVER="${VER}+${N}"
OUT="$HOME/tmp/${PKG}_${FORKVER}_amd64.deb"

BUILD=build/fork

# 1. Configure + compile (qcoro + libmocr are vendored via FetchContent — first configure needs network)
# OCR: MangaOCR via libmocr (embeds Python; runtime needs `manga_ocr` importable by python3)
cmake -S . -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DMEMENTO_RELEASE_BUILD=ON \
    -DMEMENTO_QAPPLICATION=ON \
    -DMEMENTO_OCR_SUPPORT=ON \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BUILD" -j"$(nproc)"

# 2. Stage install
STAGE="$BUILD/deb-root"
rm -rf "$STAGE"
DESTDIR="$REPO/$STAGE" cmake --install "$BUILD"

# libmocr's install exports dev headers — not wanted in a runtime deb
rm -rf "$STAGE/usr/include"

# 3. Runtime Depends via dpkg-shlibdeps (fallback to a static list)
DEPS=""
if command -v dpkg-shlibdeps >/dev/null 2>&1; then
    (
        cd "$STAGE"
        mkdir -p debian && : > debian/control
        # -lusr/lib lets shlibdeps resolve the bundled libmocr libs; scan them too
        dpkg-shlibdeps -lusr/lib -O usr/bin/shiroikuma-yosuga usr/lib/libmocr.so usr/lib/libmocr++.so 2>/dev/null | sed -n 's/^shlibs:Depends=//p'
        rm -rf debian
    ) > "$BUILD/deps.txt" || true
    DEPS="$(cat "$BUILD/deps.txt")"
fi
[[ -n "$DEPS" ]] || DEPS="libqt6widgets6 (>= 6.9), libqt6svg6, libqt6qml6, libmpv2, libjson-c5, libzip4t64, libsqlite3-0"

# QML runtime modules are loaded as plugins — invisible to dpkg-shlibdeps.
# Keep in sync with the `import Qt*` set under src/qml/ and src/quick/.
QML_DEPS="qml6-module-qtcore, qml6-module-qtqml, qml6-module-qtqml-models, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-dialogs, qml6-module-qtquick-layouts, qml6-module-qtquick-shapes, qml6-module-qtquick-window, qml6-module-qtquick-templates"
DEPS="$DEPS, $QML_DEPS"

# 4. Control file + package
mkdir -p "$STAGE/DEBIAN"
INSTALLED_SIZE=$(du -sk "$STAGE" --exclude=DEBIAN | cut -f1)
cat > "$STAGE/DEBIAN/control" <<EOF
Package: ${PKG}
Version: ${FORKVER}
Architecture: amd64
Maintainer: 白い熊 <claude.ai@sumou.com>
Installed-Size: ${INSTALLED_SIZE}
Depends: ${DEPS}
Recommends: yt-dlp, fonts-noto-cjk
Section: video
Priority: optional
Homepage: https://github.com/ShiroiKuma0/shiroikuma-yosuga
Description: 白い熊 縁 — mpv-based video player for studying Japanese
 shiroikuma fork of Memento: an mpv-based video player with built-in
 subtitle dictionary lookup and Anki integration for studying Japanese.
EOF

# OCR runtime dep (manga-ocr) is PyPI-only — remind the installer if missing
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    # manga_ocr may live in the system site or in the installing user's
    # ~/.local site (pip --user under sudo) — probe both before nagging
    installed=no
    if python3 -c "import manga_ocr" >/dev/null 2>&1; then
        installed=yes
    elif [ -n "$SUDO_USER" ] && \
        runuser -u "$SUDO_USER" -- python3 -c "import manga_ocr" \
            >/dev/null 2>&1; then
        installed=yes
    fi
    if [ "$installed" = no ]; then
        echo ""
        echo "shiroikuma-yosuga: OCR support (MangaOCR) needs the Python package"
        echo "'manga_ocr', which has no Debian package. Make sure you run:"
        echo ""
        echo "    pip3 install --user --break-system-packages manga-ocr"
        echo ""
        echo "as your normal user (not root), or OCR will stay disabled at runtime."
        echo "First OCR use downloads the kha-white/manga-ocr-base model."
        echo ""
    fi
fi
exit 0
EOF
chmod 755 "$STAGE/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$STAGE" "$OUT"

# 5. Bump BUILD_NUMBER
sed -i -E "s/^BUILD_NUMBER=[0-9]+$/BUILD_NUMBER=$((N + 1))/" fork.properties

echo
echo "BUILT: $OUT"
echo "BUILD_NUMBER bumped to $((N + 1))"
