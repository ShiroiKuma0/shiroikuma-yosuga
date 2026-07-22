---
name: upstream-new-version
description: Sync the shiroikuma-yosuga fork with a new upstream version of ripose-jp/Memento — advance master to the new upstream state, rebase custom (all our patches) on top, and build the new +1 deb. Use when 白い熊 says a new upstream Memento version is out, asks to update/sync to upstream, check for a new version, or rebase onto the latest upstream.
---

# Sync shiroikuma-yosuga with a new upstream Memento version

Goal: move `master` to the new upstream state, replay our `custom` customizations on top,
and produce a fresh `+1` build.

> **Never `git push` or `git commit` unprompted.** After the rebase + build you stop and let
> 白い熊 test; you only push when they explicitly say **"Push"**.

## Background — branch model & versioning

- `origin` = `git@github.com:ShiroiKuma0/shiroikuma-yosuga.git` (ssh, push here).
- `upstream` = `https://github.com/ripose-jp/Memento.git` (fetch only).
- **`master` mirrors `upstream/master`**, fast-forward only — no fork work ever lives on
  `master`. (Memento's release tags lag master; we ride the master tip, like
  shiroikuma-jiyudoga rides FreeTube's development tip.)
- **`custom`** carries all our work, **rebased** onto `master` on each sync (linear history,
  easy to audit with `git log master..custom`).
- Fork version = `<upstream CMakeLists.txt project VERSION>+<BUILD_NUMBER>`.
  `BUILD_NUMBER` lives in `fork.properties`; it **resets to 1** whenever the upstream
  `VERSION` changes, and just keeps counting when only upstream commits (same VERSION) land.

## Steps

### 1. Check upstream

```bash
git fetch upstream --tags
# new work our master doesn't have:
git log --oneline master..upstream/master
# newest release tag (context only — we base on the master tip):
git tag --sort=-version:refname | head -3
```

Also check releases: `gh api repos/ripose-jp/Memento/releases/latest --jq '{tag_name, published_at}'`.
If `master..upstream/master` is empty, stop and report "already current".

### 2. ⛔ PROCEED GATE — new-features table BEFORE any rebasing (hard rule)

**Before touching any branch**, present 白い熊 a **descriptive table of the new features**
introduced by the new upstream version, and **wait for an explicit "proceed"**. Build the
table from `git log master..upstream/master` (plus the GitHub release notes of any new
release tag in that range). Format:

| Area | Change | What it means for us |
| --- | --- | --- |
| (player, dictionary, Anki, UI, build, …) | short description of the feature/fix | impact on our patches / rebranding |

Do **not** advance `master`, rebase, or build until 白い熊 answers "proceed".

### 3. Advance `master` and rebase `custom`

1. `git checkout master && git merge --ff-only upstream/master`
2. `git checkout custom && git rebase master`
3. Resolve conflicts so **all** our customizations survive (see the table in `CLAUDE.md`).
   Reconcile, don't drop: if upstream restructured a file we patch, port our change to the
   new structure rather than forcing the old diff. **If conflicts are significant, stop and
   plan with 白い熊 before continuing.**
   Conflict hotspots: `res/memento.desktop`, `res/memento.svg` (our traced icon),
   `README.md`, any `src/` files carrying rebranding (about/help text, URLs) or feature
   patches, `CMakeLists.txt`.

### 4. Update versioning

- If the upstream `project(... VERSION x.y.z)` in `CMakeLists.txt` changed:
  **reset `BUILD_NUMBER=1`** in `fork.properties`.
- If only commits moved (same VERSION), leave `BUILD_NUMBER` counting.

### 5. Verify our customizations are intact

Run through the customization table in `CLAUDE.md` (app label `白い熊 縁`, deb package
`shiroikuma-yosuga`, black-yellow traced icon, our GitHub links/branding everywhere, all
feature patches, build scripts, skills).

### 6. Build the new `+1`

Build via the **build-fork** skill (`_scripts/build-fork.sh`) — it delivers the deb to
`~/tmp/` and bumps `BUILD_NUMBER`. Announce what was built.

### 7. Stop

Let 白い熊 test. Commit/push only on their explicit **"Push"**. `master` pushes fast-forward
(`git push origin master`); the rebase rewrites `custom`'s history, so
`git push --force-with-lease origin custom`.

## Hard rules

- The ⛔ proceed gate in step 2 is mandatory — never rebase before 白い熊 says "proceed".
- Never commit/push unprompted; wait for "Push".
- Keep our changes a **small, legible layer** on top of upstream — rebase (linear), never
  merge upstream into `custom`.
- The installed binary is `shiroikuma-yosuga` (via `MEMENTO_OUTPUT_NAME` in
  `src/CMakeLists.txt`), but do **not** rename the CMake target or any internal
  namespace (`memento` target, `Ripose.Memento` QML module, data dir) — that would make
  every rebase a mass-conflict.
- No Claude attribution in commits (see `CLAUDE.md`).
