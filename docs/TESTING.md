# Testing and release checklist

No release (v0.1.0) until every **Required** item passes on a real Mac.

## Where we left off (2026-11-18)

Work moved to another Mac for disk-space reasons. On the first Mac:

- A wrapper built **by hand** with the same steps as `install.sh` installed the official
  `Warframe.msi`, and the launcher was downloading the game (13 GB done, 5 MB/s) with DXMT.
- `install.sh --skip-installer`, `tools/renderer.sh`, `tools/status.sh` and
  `uninstall.sh --delete` were tested on a throwaway copy.
- The full `./install.sh` (with the Warframe installer) has **not** been run end to end.

Next on the new Mac:

1. `./install.sh --launch` from a clean state, and tick section 1.
2. Let the launcher finish the download, then play-test both backends (section 2).
3. Answer the open questions in section 4, update docs and defaults.
4. Cut v0.1.0 (section 5).

## Test machines

| Mac | macOS | Date | Tester | Result |
|---|---|---|---|---|
| MacBook Pro M2 Pro | 27.2 | 2026-11-18 | maintainer | in progress |

## 1. Install (Required)

- [ ] `./install.sh` on a Mac with no previous wrapper completes all steps
- [ ] `--msi` with a local installer works
- [x] Re-running uses the cached template and engine ("already downloaded")
- [x] Refuses to overwrite an existing app
- [x] Wrapper build, prefix creation and settings (`--skip-installer`, 1 min 35 s)
- [x] Rejects unknown options and renderers
- [x] Manual install of the MSI with `msiexec /qn` succeeds (`Return value 1`)
- [x] Launcher opens, reaches Warframe servers and starts downloading

## 2. Game (Required)

- [ ] Full download completes
- [ ] Log in to an account
- [ ] Orbiter loads
- [ ] One full mission, with audio
- [ ] Alt-tab, fullscreen and windowed modes, resolution change
- [ ] Quit and reopen; game update through the launcher

Record for each backend:

| Backend | DirectX | Launches | Avg FPS (settings) | Stutter | Crashes | Notes |
|---|---|---|---|---|---|---|
| DXMT | 11 | | | | | |
| D3DMetal | 11 | | | | | |
| D3DMetal | 12 | | | | | |

## 3. Tools (Required)

- [x] `tools/status.sh` shows engine, backend, game data size and launcher log
- [x] `tools/renderer.sh d3dmetal` / `dxmt` switch the setting
- [ ] The switched backend is really used on the next launch
- [ ] `./uninstall.sh` moves the app to the Trash
- [x] `./uninstall.sh --delete` removes it
- [x] `./uninstall.sh` refuses an app not built by `install.sh` without `--force`
- [x] Mole clean with the whitelist leaves the running launcher and game data intact

## 4. Open questions

- [ ] Why the launcher installed the game in `C:\windows\Warframe` and not in
      `C:\Program Files\Warframe`, and whether the script should preset the folder.
- [ ] Which backend gives the best result, to choose the default.
- [ ] Can the launcher's DirectX setting be preset by the script?
- [ ] Is the `+loaddll` Wine debug channel in the template worth turning off for performance?

## 5. Before publishing

- [x] Choose the repository name (`Javiergptrd/warframe-macos-wrapper`, private for now)
- [ ] Decide whether to make the repository public
- [ ] Remove the "work in progress" banner from both READMEs
- [ ] Update `WFW_VERSION` in `lib/common.sh` and `CHANGELOG.md`
- [ ] Check that pinned template/engine URLs and hashes still resolve
- [ ] Review the README disclaimer and THIRD_PARTY.md
- [ ] Tag the release (`v0.1.0`) and attach the source zip only (no binaries)
