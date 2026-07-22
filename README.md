<div align="center">

<img src="res/memento.svg" width="120" alt="白い熊 縁 app icon" />

# 白い熊 縁

**An mpv-based video player for studying Japanese.**

A fork of [Memento](https://github.com/ripose-jp/Memento) (GPL-2.0) with **major additions**:
a native Tuxedo OS / Debian `.deb` package, Qt 6.9.2 compatibility fixes the upstream app
lacks, a secondary subtitle that stays up as long as the primary one, a fully stylable
dictionary popup (fonts, colors, tag colors, background), clean application exit, a quiet
launch, and the 白い熊 black-yellow identity.

Grammar-aware subtitle search, Yomichan-style dictionary lookup and Kanji cards, Anki card
creation through [AnkiConnect](https://ankiweb.net/shared/info/2055492159), full mpv
configuration support — packaged for the desktop it actually runs on.

**📥 Latest release: [`2.0.2+16`](https://github.com/ShiroiKuma0/shiroikuma-yosuga/releases/latest)** — [all releases & downloads »](https://github.com/ShiroiKuma0/shiroikuma-yosuga/releases)

</div>

---

## 📦 Native amd64 `.deb` for Tuxedo OS

Upstream ships no Linux binary package. This fork builds a proper `shiroikuma-yosuga`
`.deb` against the system Qt 6.9.2 and libmpv — runtime dependencies computed with
`dpkg-shlibdeps` plus the QML modules the engine loads at runtime, so
`sudo apt install ./shiroikuma-yosuga_<ver>_amd64.deb` just works. The binary installs as
`/usr/bin/shiroikuma-yosuga`.

---

## 🛠 Runs on Qt 6.9.2 — upstream doesn't

Stock Memento (including the `v2.0.2` release) binds the read-only `ComboBox.currentValue`
across its option pages and aliases it in the Anki note editor — the Qt 6.9.2 QML engine
refuses to load the component tree and **the app never starts**. This fork replaces every
site with the supported `indexOfValue` sync, with async re-resolution for the Anki
deck/model lists.

---

## 🕒 Secondary subtitle held until the primary ends

mpv only draws the secondary (e.g. English) line inside its own timing window — with
pause-at-subtitle-end it routinely vanishes while the Japanese line is still on screen. The
fork caches the overlapping secondary line and keeps rendering it — with mpv's own
`sub-*` style (font, colors, border, `mpv.conf` included) — until the primary line it
overlapped ends. Its top offset is a setting applied to both mpv's renderer and the held
overlay, and like the primary's bottom offset it is absolute: an offset that clears the
top toolbar never jumps when the toolbar appears.

---

## 🎨 Style every corner of the dictionary popup

Upstream lets you pick fonts; the fork opens the rest. Every search category — expression,
reading, conjugation explanation, tags, glossary, kanji — gets a point-size and a text
color setting, the popup itself gets a background color, and all eleven tag-chip background
colors (name, expression, popular, frequent, archaism, dictionary, frequency, part of
speech, search, pitch accent, other) are configurable. Colors default to the theme, so
nothing changes until you say so.

---

## 🚪 Clean exit, quiet launch

Closing the main window actually quits: stock keeps a hidden helper window alive, Qt's
last-window-closed quit never fires, and the process has to be `^C`-killed. And the launch
console is silent: upstream forces the org.kde.breeze QML style, which floods four
`SafeArea` TypeErrors per ComboBox on Qt 6.9.2 — the fork keeps the clean platform default
(`QT_QUICK_CONTROLS_STYLE` still overrides).

---

## 🐻 白い熊 identity

The black-yellow house identity throughout: the Memento crescent as a black-fill,
yellow-edge trace on a black card (launcher SVG + all window-icon sizes), the app named
**白い熊 縁** everywhere — window title, About, menus, help and option texts — and the
in-app update check pointing at this repo's releases.

---

## Built on Memento

A fork of [Memento](https://github.com/ripose-jp/Memento) by ripose — all player,
dictionary, and Anki machinery is upstream's work. `master` mirrors upstream; everything
above lives as a small rebasable layer on `custom`. The code remains under GPL-2.0.

## Building

```bash
git clone git@github.com:ShiroiKuma0/shiroikuma-yosuga.git
cd shiroikuma-yosuga
_scripts/build-fork.sh   # → ~/tmp/shiroikuma-yosuga_<ver>_amd64.deb
```

Toolchain: Qt 6.9+ (base, svg, declarative + private headers, tools), libmpv, json-c,
libzip, sqlite3, CMake + Ninja, dpkg-dev. QCoro is fetched automatically by CMake at
configure time.
