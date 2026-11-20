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
| Mac mini M4 | 15.7.7 | 2026-11-18 | maintainer | install passed; orbiter runs on DXMT |

## 1. Install (Required)

- [x] `./install.sh` on a Mac with no previous wrapper completes all steps (Mac mini M4, macOS 15.7.7)
- [ ] `--msi` with a local installer works
- [x] Re-running uses the cached template and engine ("already downloaded")
- [x] Refuses to overwrite an existing app
- [x] Wrapper build, prefix creation and settings (`--skip-installer`, 1 min 35 s)
- [x] Rejects unknown options and renderers
- [x] Manual install of the MSI with `msiexec /qn` succeeds (`Return value 1`)
- [x] Launcher opens, reaches Warframe servers and starts downloading

## 2. Game (Required)

- [x] Full download completes
- [x] Log in to an account
- [x] Orbiter loads
- [x] One full mission, with audio (DXMT)
- [x] Alt-tab, fullscreen and windowed modes, resolution change
      - [x] Alt-tab (Cmd+Tab) in borderless, DXMT
      - [x] Exclusive fullscreen tested: **fails on DXMT**: it picks 800×600, loses focus, minimizes
            and resets the display in a loop (blank screen, glitches). Use Borderless.
            Fix: set `Graphics.WindowMode=MODE_BORDERLESS` in `EE.cfg` with the game closed.
      - [x] Windowed mode and resolution change (DXMT, 2026-11-19): Borderless → Windowed 800×600 →
            1720×667 → 1720×720 → Borderless, each with a clean `ResetDriver`, no graphics errors
- [ ] Quit and reopen; game update through the launcher
      - [x] Quit and reopen (clean shutdown, launcher restarts the game)
      - [ ] Game update through the launcher (wait for a Warframe update)

Record for each backend:

| Backend | DirectX | Launches | Avg FPS (settings) | Stutter | Crashes | Notes |
|---|---|---|---|---|---|---|
| DXMT | 11 | yes | 60–90 orbiter (Medium, 1080p, M4 10-core GPU); capped at 60 in a mission | rare: 1 shader upload (26 ms) in a 4-min mission | none | Mission: Weekly Ayatan hunt (Orokin Derelict). Streaming averaged 8.2 ms/frame mid-mission. 60 Hz display |
| DXMT | 11 | yes | Plains of Eidolon open world: streaming avg 7.9 ms/frame, 13 of 103 batches over 16.7 ms, none over 25 ms | only during loading screens (up to 0.5 s) | none | 2026-11-19, MSI 3440×1440 @144 Hz ultrawide, ~20 bounty stages + Kronia Relay + Lua quest. Game rendered at **1720×720** (see section 4) |
| DXMT + Retina | 11 | yes | 3440×1440 native, Medium: mission streaming avg 22.7 ms/frame, frames mostly 28–34 ms (~30–35 FPS) | frequent | none | 2026-11-19, quest "The Relic" (Earth). Sharper but ~2.9× the frame cost of 1720×720 (7.9 ms). Next: in-game FSR upscaling |
| DXMT + Retina + FSR 3 Quality | 11 | yes | 3440×1440 output, Plains of Eidolon: avg 23.2 ms/frame (median 23), 26 of 33 batches over 16.7 ms | frequent | none | 2026-11-19. No gain over native Retina (22.7 ms); small sample. 1720×720 without upscaling: 7.9 ms on the same map |
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
      Same result on the Mac mini M4, so it is the launcher's default under Wine, not a one-off.
- [ ] Which backend gives the best result, to choose the default.
- [ ] Can the launcher's DirectX setting be preset by the script?
- [ ] **Retina / HiDPI:** on a scaled display (3440×1440 shown as "looks like 1720×720") the game
      only sees 1720×720 and renders at half resolution, which macOS then upscales. Wine's
      `HKCU\Software\Wine\Mac Driver` `RetinaMode="y"` is not set in the prefix. Test setting it
      (game sharper, FPS lower) and decide whether `install.sh` should set it or offer it as a tool.
      Tested 2026-11-19: with it, the game renders at 3440×1440 (confirmed in EE.log) but drops to
      ~30–35 FPS on Medium with DXMT on an M4. Try it with in-game FSR before deciding.
      Presetting FSR by writing `Graphics.UpscaleMethod=UM_FSR3` to `EE.cfg` does not stick: the game
      creates the FSR 3 context, logs "Upscaling settings out of sync" and falls back to
      `UM_DISABLED`. FSR must be set in Options → Display. (Upscalers in this build: FSR 3, DLSS, MFSR.)
      FSR 3 Quality set in the menu (confirmed in EE.log) did not lower frame cost on the Plains (23.2 ms
      vs 7.9 ms at 1720×720), so on an M4 Retina mode costs ~3× and FSR does not win it back.
      **Decision (2026-11-19):** `install.sh` keeps Retina mode off by default. A future optional tool
      could turn it on for stronger GPUs (M-series Pro/Max), to be tested there.
      Retina, no upscaling, Corpus ship quest "The Final Test": avg 14.5 ms/frame (lighter scene than "The Relic").
- [x] `EE.log` is overwritten on every launch, so a session's log is lost when the game restarts.
      `tools/watch-log.sh` now saves the full log to `SharedSupport/Logs/EE-<date>-<time>.log`.
- [ ] Should `install.sh` preset `Graphics.WindowMode=MODE_BORDERLESS` in `EE.cfg`, and does
      exclusive fullscreen work on D3DMetal?
- [ ] Is the `+loaddll` Wine debug channel in the template worth turning off for performance?

## 5. Before publishing

- [x] Choose the repository name (`Javiergptrd/warframe-macos-wrapper`, private for now)
- [x] Decide whether to make the repository public (public since 2026-11-18)
- [ ] Remove the "work in progress" banner from both READMEs
- [ ] Update `WFW_VERSION` in `lib/common.sh` and `CHANGELOG.md`
- [x] Check that pinned template/engine URLs and hashes still resolve (2026-11-18, install on M4)
- [ ] Review the README disclaimer and THIRD_PARTY.md
- [ ] Tag the release (`v0.1.0`) and attach the source zip only (no binaries)
