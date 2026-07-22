<div align="center">

<img src="res/memento.svg" width="120" alt="白い熊 縁 app icon" />

# 白い熊 縁

**An mpv-based video player for studying Japanese.**

白い熊's fork of [Memento](https://github.com/ripose-jp/Memento) (GPL-2.0) — grammar-aware
subtitle search, Yomichan-style dictionary lookup and Kanji cards, Anki card creation
through [AnkiConnect](https://ankiweb.net/shared/info/2055492159), full mpv configuration
support — rebranded and built as a native **GNU/Linux amd64 `.deb`** for Tuxedo OS /
Ubuntu / Debian.

**📥 Latest release: [releases & downloads »](https://github.com/ShiroiKuma0/shiroikuma-yosuga/releases)**

</div>

---

## Fork facts

- **Package**: `shiroikuma-yosuga`, installs `usr/bin/shiroikuma-yosuga`; desktop entry
  **白い熊 縁** with the black-yellow traced crescent icon.
- **Versioning**: `<upstream version>+<N>` — the fork build counter `+N` bumps on every
  build and resets on each new upstream version.
- **Branches**: `master` mirrors [upstream](https://github.com/ripose-jp/Memento) `master`
  (fast-forward only); all fork work lives on `custom`, rebased on top.
- **Update check** inside the app points at this repo's releases.

## Building

```bash
_scripts/build-fork.sh   # → ~/tmp/shiroikuma-yosuga_<ver>_amd64.deb
```

Toolchain: Qt 6.9+, libmpv, json-c, libzip, sqlite3, CMake + Ninja. QCoro is fetched
automatically by CMake at configure time.

Install with:

```bash
sudo apt install ~/tmp/shiroikuma-yosuga_<ver>_amd64.deb
```

## Dictionaries

See the [upstream README](https://github.com/ripose-jp/Memento#dictionaries) for the full,
maintained list of compatible Yomichan/Yomitan dictionaries (JMdict, JMnedict, KANJIDIC,
pitch-accent and frequency dictionaries, …).

## Credits

All player, dictionary, and Anki machinery is the work of
[ripose-jp/Memento](https://github.com/ripose-jp/Memento) and its contributors, GPL-2.0.
This fork carries the 白い熊 identity, packaging, and whatever features land on `custom`.
