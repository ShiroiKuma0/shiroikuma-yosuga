# Changelog

This file carries the release history of **白い熊 縁** (shiroikuma-yosuga), 白い熊's fork of
[Memento](https://github.com/ripose-jp/Memento). Upstream keeps no changelog of its own — its
releases are listed at <https://github.com/ripose-jp/Memento/releases>. Every entry below is the
delta since the previous fork release; each says which upstream release it is built on.
Release tags carry no `v`; from `2.0.2+032` on, the build counter is zero-padded to three digits.

## 白い熊 縁 2.0.2+032 — 2026-09-19

Built on upstream Memento `v2.0.2`.

- **First English subtitle track selected as the Second Track by default** — on every file load the fork sets `secondary-sid` to the first English subtitle track: by language tag (`en`, `eng`, regional variants such as `en-US`) or, for tracks without a usable tag, by a title that is the bare code or contains "English" — the common case of an embedded track labelled just `en`. With `slang=jpn` this gives Japanese below and English above without opening the Subtitle menu. A file whose only English track is already the primary is left alone (mpv refuses to select one track in both slots). The track list is refreshed synchronously in the file-loaded handler, since mpv's observed `track-list/count` arrives after the regular events and not at all when consecutive files have the same number of tracks.
- **Zero-padded build numbering** — the build counter is padded to three digits in the deb version, the artifact name and the release tag (`2.0.2+032`), so file lists and tags sort in build order. Older tags stay as published (`2.0.2+30`); dpkg orders `2.0.2+032` after `2.0.2+31`, so upgrading in place works.
- **About window shows the full version** — `Version 2.0.2+032` instead of the bare upstream `2.0.2`; the padded counter is compiled in as `MEMENTO_BUILD_NUMBER` and exposed as `Features.buildNumber`.

## 白い熊 縁 2.0.2+30 — 2026-07-24

Built on upstream Memento `v2.0.2`.

- **The mouse forward button (BTN_EXTRA / X11 button 9) starts OCR selection** — exactly like the Start OCR keybind, including reusing a held frozen frame for rescans. The button is no longer forwarded to mpv.

## 白い熊 縁 2.0.2+29 — 2026-07-24

Built on upstream Memento `v2.0.2`.

- **Drag over the held frame starts the next selection** — while the frozen frame is displayed, the selection overlay stays interactive: a left press re-enters OCR mode implicitly (dismissing any open popup) and a drag selects the next region, so scanning several words from one subtitle needs no repeated Start OCR. A bare click still only dismisses the popup and keeps the frame; right-click and Escape abandon it. The crosshair cursor shown over the held frame now matches what the mouse actually does.

## 白い熊 縁 2.0.2+28 — 2026-07-24

Built on upstream Memento `v2.0.2`.

- **Built-in MangaOCR subtitle scanning** — `MEMENTO_OCR_SUPPORT` is now compiled into the deb (GPU-accelerated via the `manga-ocr` Python stack, `kha-white/manga-ocr-base`), aimed at bitmap subtitle tracks (Blu-ray PGS, DVD) that hover lookup cannot read.
- **Frozen-frame scanning** — Ctrl+L freezes the player: the composed window (video + mpv subtitles + the fork's QML subtitle overlays) is grabbed and cropped to the player, correctly under fractional display scaling (1.25×), then displayed over the video and OCRed. This is what the user sees, pixel for pixel — an mpv re-render at the pause-at-subtitle-end boundary drops the line, and is not used. Scans and rescans are immune to mpv scripts (auto-pause, sub-skip) seeking or unpausing underneath; the player is re-paused if anything unpauses it mid-selection.
- **OCR results in the definition popup** — recognition opens the regular dictionary popup anchored just above the selection rectangle (below only when there is no room), instead of the docked auxiliary search pane. OCR results ignore playback pause/position noise, so script activity cannot clear them.
- **Deliberate dismissal flow** — while the frozen frame is up, a click only closes the popup; the frame (and its subtitle) stays for further Ctrl+L scans of the same line. A key press (space, seek keys), a later click, Escape, or a file change releases it and forwards control to the player.
- **Model warm-up at mode entry** — the OCR model starts loading the moment Ctrl+L is pressed, so the selection drag absorbs the one-time load; later scans are sub-second.
- **Fully offline model loads** — when the configured model is already in the local Hugging Face cache, the app sets `HF_HUB_OFFLINE=1` at startup: no Hub version pings, no unauthenticated-request warnings. First-run downloads still work; user-set `HF_HUB_OFFLINE`/`TRANSFORMERS_OFFLINE` are respected.
- **OCR packaging** — the deb bundles `libmocr`/`libmocr++` (dev headers pruned), `dpkg-shlibdeps` resolves the bundled libraries so `libpython3.12t64` lands in `Depends`, and the postinst probes for the `manga_ocr` package (system site and the installing user's `~/.local` via `SUDO_USER`) and prints the pip reminder only when it is genuinely missing.
- **Yellow popup lining** — `MementoPalette.border` is the fork yellow (`#FFFF00`): the dictionary popup border, the separators between entries, kanji grids and thumbnail borders all follow the black-yellow identity.

## 白い熊 縁 2.0.2+16 — 2026-07-22

Built on upstream Memento `v2.0.2`.

- **Fix: files passed on the command line reliably enter the recents list.** The QML `fileLoaded` handler read `player.state.path`, an asynchronously propagated mpv property — for command-line-loaded files (e.g. the 自由動画 study export spawning the player) the load event won the race, the path read back empty, and the file never registered. The `MPV_EVENT_FILE_LOADED` handler now fetches the path synchronously from mpv and carries it in the `fileLoaded` signal, and recents are persisted to disk immediately on add instead of only at clean shutdown.

## 白い熊 縁 2.0.2+15 — 2026-07-22

Built on upstream Memento `v2.0.2`.

- **Fix: held secondary subtitle no longer invents a black background.** The overlay painted mpv's `sub-back-color` unconditionally — but mpv 0.41 defaults that option to `#AF000000` (near-opaque black) and only paints it in the box border styles, so the held line showed a black box that neither mpv's own render nor the app settings ever display. The overlay now reads `sub-border-style` and matches mpv's rules exactly: no background with the default `outline-and-shadow`, `sub-back-color` for `background-box`, the outline color for `opaque-box`.

## 白い熊 縁 2.0.2+14 — 2026-07-22

Built on upstream Memento `v2.0.2`.

### Secondary subtitle
- **Held secondary subtitle**: the secondary (e.g. English) line is cached and kept on screen past its own mpv timing window, for as long as the primary (Japanese) line it overlapped is still up — fixes the empty top pane with pause-at-subtitle-end.
- The held line renders with **mpv's own subtitle style** — `sub-font`, `sub-color`, `sub-border-color`/size, `sub-back-color`, bold/italic, `sub-font-size × sub-scale` (720-line-relative), `mpv.conf` respected; mpv color strings parsed in both `#(AA)RRGGBB` and `r/g/b[/a]` float forms.
- **Secondary subtitle top offset** setting (Interface ▸ Subtitle, fraction of window height, default 0.02). Applied to both renderers — mpv's native secondary subtitle via `secondary-sub-pos` (pushed live on change and on every file load) and the held overlay. The offset is absolute and only clamped by the menu height, so an offset that clears the top toolbar never jumps when the toolbar fades in — same behavior the primary subtitle's bottom offset always had.

### Dictionary popup styling (Interface ▸ Search / Tag Colors / Popup)
- **Per-category point size**: a Size spinbox for each of the six search categories — term expression, term reading, conjugation explanation, tag, glossary, kanji — editing the size stored in the existing font settings (existing configs carry over).
- **Per-category text color** for the same six categories. Default "transparent" = theme text color (tags default to the white the chips always used), so appearance is unchanged until set.
- **Popup background color** next to popup width/height. Default transparent = theme window color; the chosen color also feeds the canvas color that structured glossary rendering uses for contrast decisions. Applies to the hover popup, the subtitle-list popup, and the auxiliary search pane.
- **All eleven tag-chip background colors configurable** in a new Tag Colors box: name, expression, popular, frequent, archaism, dictionary, frequency, part of speech, search, pitch accent dictionary, and other (fallback). The dictionary and frequency colors also drive the dictionary-name and frequency chips. Defaults are upstream's colors.
- Fix: the glossary text had **no explicit color** upstream (`TextEdit` black regardless of theme) — it now follows the theme text color when unset.

### Icon
- The crescent's yellow trace thickened from ~2% to ~5.5% of the icon width (matching the 自由動画 house line weight) so it stays visible at taskbar sizes; `memento.ico` regenerated at all seven sizes from the SVG.

## 白い熊 縁 2.0.2+8 — 2026-07-22

First release, built on upstream Memento `2.0.2` (master tip, `v2.0.2-10-g67ba6a9`). Everything on top of stock:

### Packaging & build pipeline
- Native **amd64 `.deb`** package `shiroikuma-yosuga` — upstream ships no Linux binary package. Built against system Qt 6.9.2 and libmpv 0.41 via `_scripts/build-fork.sh`: CMake/Ninja release build (`MEMENTO_RELEASE_BUILD=ON`, `MEMENTO_QAPPLICATION=ON`), staged `DESTDIR` install, `dpkg-deb`.
- Runtime `Depends` computed with `dpkg-shlibdeps`, **plus** the `qml6-module-*` runtime modules the QML engine loads as plugins (invisible to shlibdeps — the deb installs and runs on a fresh system). `Recommends: yt-dlp, fonts-noto-cjk`.
- Fork versioning `<upstream version>+<N>` (`fork.properties` build counter, bumped every build, reset on a new upstream version); artifact naming `shiroikuma-yosuga_<ver>_amd64.deb`.
- Binary installs as `/usr/bin/shiroikuma-yosuga` (via the upstream `MEMENTO_OUTPUT_NAME` hook; CMake target and internal namespaces stay `memento` for rebase hygiene).
- Fork workflow codified: `master` mirrors upstream ff-only, all work rebased on `custom`; repo skills for the canonical build and the proceed-gated upstream sync.

### Fixes upstream lacks
- **App starts on Qt 6.9.2 at all**: stock (incl. the `v2.0.2` release) binds the read-only `ComboBox.currentValue` on eight option-page combos and aliases it in the Anki note editor (`AnkiNoteBox.qml` `currentDeck`/`currentModel`) — the 6.9.2 QML engine rejects the whole component tree (`QQmlApplicationEngine failed to load component`). Replaced every site with the supported `currentIndex = indexOfValue(...)` sync; the Anki deck/model selections re-resolve when the async lists arrive.
- **Clean exit**: closing the main window left the process running (`^C` required) — the app keeps a 1×1 X helper window alive, so Qt's last-window-closed auto-quit never fires. The root window now quits explicitly on close; mpv core, Lua-script and decoder threads all shut down within a second (verified under Xvfb + openbox).
- **Quiet launch**: upstream force-switches the QML style to `org.kde.breeze`, whose ComboBox `SafeArea` margin bindings throw four TypeErrors per ComboBox on Qt 6.9.2, flooding the console. The fork keeps the platform default (`org.kde.desktop` on KDE — zero QML errors, measured against Fusion/Basic/breeze); `QT_QUICK_CONTROLS_STYLE` still overrides.

### Identity & branding
- Black-yellow traced icon: the Memento crescent as a black-fill / yellow `#FFFF00` edge-trace on a black rounded card — launcher SVG and a regenerated multi-size window `.ico` (16–256 px).
- App label **白い熊 縁** everywhere: desktop entry, window title, About window, `&About` menu, preference-path hints, first-launch Auto Update dialog, Anki marker help and template-processor help, subtitle/audio option texts, console diagnostics (SQLite error, settings-migration warning), `--help` usage.
- Desktop entry: `Name=白い熊 縁`, `Exec=shiroikuma-yosuga`.
- All GitHub links point at this repo (About window, update-check constants, CMake homepage); the About window credits the upstream project with a link. The in-app update check reads this repo's releases and understands the fork's `<ver>+<N>` tag scheme.
- Fork README telling the fork's story; license headers and internal namespaces untouched (GPL-2.0).
