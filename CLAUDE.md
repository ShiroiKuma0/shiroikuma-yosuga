# CLAUDE.md — guide for Claude Code in this repo

**shiroikuma-yosuga** (白い熊 縁) — 白い熊's fork of
[Memento](https://github.com/ripose-jp/Memento), an mpv-based C++/Qt 6 video player for
studying Japanese (built-in subtitle dictionary lookup, Anki integration). We build **only**
the GNU/Linux amd64 `.deb` for Tuxedo OS.

## Read this first

Before any work, read **`.claude/skills/build-fork/SKILL.md`** (canonical build) and
**`.claude/skills/upstream-new-version/SKILL.md`** (upstream sync — with its mandatory
⛔ proceed gate).

## Fork workflow

### Remotes & branches
- `origin` → `git@github.com:ShiroiKuma0/shiroikuma-yosuga` (push here).
- `upstream` → `https://github.com/ripose-jp/Memento` (fetch only). **`master` mirrors
  `upstream/master`**, ff-only — no fork work on `master`.
- `custom` — all our work, **rebased** onto `master` on each upstream sync (linear history;
  audit with `git log master..custom`).

### Our customizations (identity + build)
| What | Value | Where |
| --- | --- | --- |
| Deb package | `shiroikuma-yosuga` | `_scripts/build-fork.sh` control file |
| App label | `白い熊 縁` | `res/memento.desktop` `Name` (+ window/about titles in the rebrand layer) |
| Installed binary | `shiroikuma-yosuga` via `MEMENTO_OUTPUT_NAME` (CMake **target** stays `memento` — never rename the target or internal namespaces) | `src/CMakeLists.txt` |
| Version | `<upstream CMakeLists.txt VERSION>+<N>` | `fork.properties` → `BUILD_NUMBER` (bumped every build; reset to 1 on a new upstream VERSION) |
| Icon | black-yellow traced crescent (black fill, yellow `#FFFF00` edge-trace on black) | `res/memento.svg` (installed icon), `res/memento.ico`/`.icns` masters |
| Branding / links | our name + `https://github.com/ShiroiKuma0/shiroikuma-yosuga` everywhere upstream's name/links appear (README, Help/About, update checks) | rebrand commits on `custom` |
| Keystore | `~/.android-keystores/shiroikuma-yosuga.jks`, alias `yosuga` (recorded in the 暗号 org file; NOT used by the deb pipeline — reserved for release signing / any future Android build) | — |
| Artifact | `~/tmp/shiroikuma-yosuga_<ver>_amd64.deb` | `_scripts/build-fork.sh` |
| Qt 6.9.2 QML load fix | upstream binds the read-only `ComboBox.currentValue` (8 option pages) and aliases it (`AnkiNoteBox.qml`) — the 6.9.2 engine refuses to load; replaced with `currentIndex = indexOfValue(...)` sync (`Component.onCompleted` / property-change + `onModelChanged` handlers). Check on every rebase whether upstream fixed it their own way — if so, drop ours. | `src/qml/options/*.qml`, `src/qml/controls/AnkiNoteBox.qml` |

### Build commands
```bash
_scripts/build-fork.sh    # canonical: release .deb → ~/tmp + BUILD_NUMBER bump
```

### Toolchain
- All system packages on Tuxedo OS: Qt 6.9.2 (`qt6-base-dev`, `qt6-svg-dev`), `libmpv-dev`
  0.41, `libjson-c-dev`, `libzip-dev`, `libsqlite3-dev`, `cmake`, `ninja-build`.
- **qcoro** is vendored via CMake `FetchContent` (`extern/CMakeLists.txt`) — first configure
  needs network. `MEMENTO_MECAB_SUPPORT` is OFF (no `libmecab-dev` on this host; see
  build-fork skill to enable).
- Build dir `build/fork/` (gitignored by upstream's `/build*/` rule).

## Architecture notes

- Qt 6 Widgets + QML hybrid (`src/qml/`, `src/quick/`); the player is libmpv rendered into
  the Qt window (`src/player/`). Dictionary machinery in `src/dict/` (Yomichan-style zip
  dictionaries, sqlite-backed), Anki Connect in `src/anki/`, subtitle handling in
  `src/subtitle/`.
- Installed files (UNIX): `usr/bin/shiroikuma-yosuga`, `usr/share/memento/translations/`
  (data dir keeps the upstream name — the binary resolves it via
  `appDir/../share/memento/translations`), `usr/share/applications/memento.desktop`
  (`Name=白い熊 縁`, `Exec=shiroikuma-yosuga`),
  `usr/share/icons/hicolor/scalable/apps/memento.svg`.

## Hard rules
- **Never commit or push on your own.** Build and let 白い熊 test; commit/push only on an
  explicit **"Push"**.
- **The ⛔ proceed gate** in upstream-new-version is mandatory: descriptive new-features
  table first, 白い熊's "proceed" before any branch is touched.
- **No Claude attribution** in commits or PRs — no `Co-Authored-By: Claude`, no "Generated
  with Claude Code". End commit messages at the last line of the body.
- Keep our changes a small, legible layer: prefer porting our patch to upstream's new
  structure over forcing old diffs.
