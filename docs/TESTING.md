# Testing checklist

No release (v0.1.0) until every **Required** item passes on a real Mac.

## Test machines

| Mac | macOS | Date | Tester | Result |
|---|---|---|---|---|
| MacBook Pro M2 Pro | 27.2 | 2026-11-18 | maintainer | in progress |
| Mac mini M4 | 15.7.7 | 2026-11-18 | maintainer | install passed; orbiter runs on DXMT |

## 1. Install (Required)

- [x] `./install.sh` on a Mac with no previous wrapper completes all steps (Mac mini M4, macOS 15.7.7)
- [ ] `--msi` with a local installer works (skipped for now: needs a second install)
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
      - [x] Exclusive fullscreen on **D3DMetal DX12** (2026-11-20, 2048×858 @144 Hz) mostly works: switching to it
            in-game first picks 800×600 (pick the resolution again), and leaving the game (Cmd+Tab) minimizes it.
            The minimize is the game's own behaviour ("Focus lost while fullscreen; minimizing..."); coming back
            restores 2048×858 after a ~1.3 s reset. No loop, unlike DXMT. Borderless is still smoother for alt-tab.
      - [x] Windowed mode and resolution change (DXMT, 2026-11-19): Borderless → Windowed 800×600 →
            1720×667 → 1720×720 → Borderless, each with a clean `ResetDriver`, no graphics errors
- [x] Quit and reopen; game update through the launcher
      - [x] Quit and reopen (clean shutdown, launcher restarts the game)
      - [x] Game update through the launcher: a small Warframe update on 2026-11-19 installed and the game ran fine (reported by the tester; the launcher log is overwritten on each start)

Record for each backend:

| Backend | DirectX | Launches | Avg FPS (settings) | Stutter | Crashes | Notes |
|---|---|---|---|---|---|---|
| DXMT | 11 | yes | 60–90 orbiter (Medium, 1080p, M4 10-core GPU); capped at 60 in a mission | rare: 1 shader upload (26 ms) in a 4-min mission | none | Mission: Weekly Ayatan hunt (Orokin Derelict). Streaming averaged 8.2 ms/frame mid-mission. 60 Hz display |
| DXMT | 11 | yes | Plains of Eidolon open world: streaming avg 7.9 ms/frame, 13 of 103 batches over 16.7 ms, none over 25 ms | only during loading screens (up to 0.5 s) | none | 2026-11-19, MSI 3440×1440 @144 Hz ultrawide, ~20 bounty stages + Kronia Relay + Lua quest. Game rendered at **1720×720** (see section 4) |
| DXMT + Retina | 11 | yes | 3440×1440 native, Medium: mission streaming avg 22.7 ms/frame, frames mostly 28–34 ms (~30–35 FPS) | frequent | none | 2026-11-19, quest "The Relic" (Earth). Sharper but ~2.9× the frame cost of 1720×720 (7.9 ms). Next: in-game FSR upscaling |
| DXMT + Retina + FSR 3 Quality | 11 | yes | 3440×1440 output, Plains of Eidolon: avg 23.2 ms/frame (median 23), 26 of 33 batches over 16.7 ms | frequent | none | 2026-11-19. No gain over native Retina (22.7 ms); small sample. 1720×720 without upscaling: 7.9 ms on the same map |
| D3DMetal | 11 | yes | Quest mission on Cetus and the Plains (`CetusInvasion`, 4-player squad): streaming avg 11.9 ms/frame (median 7), 20 of 61 batches over 16.7 ms, 9 over 25 ms, none over 50 ms. Orbiter avg 12.8 ms | one 1.6 s `Present()` stall in the orbiter, otherwise loading only | none | 2026-11-20, 1720×720 Borderless, Medium, frame cap 144 (DXMT runs were capped at 60). Confirmed loaded: `D3DMetal.framework`, D3DMetal `d3d11.dll`/`dxgi.dll`; the game sees an "AMD Compatibility Mode" adapter. Different scene from the DXMT Plains run, so compare loosely |
| D3DMetal | 12 | yes | Plains of Eidolon, **first run (cold shader cache)**: streaming avg 23.4 ms/frame (median 17), 28 of 52 batches over 16.7 ms, 25 over 25 ms, 2 over 50 ms | frequent: 347 shader pipelines (PSOs) compiled while playing (8.4 s in total, up to 105 ms each); 4 "Draw needed active-prefetch PSO" stalls of 20–120 ms | none | 2026-11-20, 1720×720 Borderless, frame cap 144. Confirmed `ID3D12Device2`, "PSO Cache Enabled". The tester felt the image looked better than on DirectX 11; the logs show no setting that differs by API. Second Plains visit in the same session (warm cache): avg 17.6 ms/frame (median 9), 7 of 20 batches over 16.7 ms, 6 over 25 ms, 1 over 50 ms; 112 PSOs compiled (2.3 s, vs 8.4 s), no draw stalls. After a game restart (2026-11-20, ~20 min on the Plains): avg 10.6 ms/frame (median 11), 17 of 235 batches over 25 ms, none over 50 ms; only 39 PSOs compiled in the first 400 s (vs 347 cold) and no compiles at startup, so the disk shader cache (`AUTOMATIC_DISK_CACHE`) works |

## 3. Tools (Required)

- [x] `tools/status.sh` shows engine, backend, game data size and launcher log
- [x] `tools/renderer.sh d3dmetal` / `dxmt` switch the setting
- [x] The switched backend is really used on the next launch (D3DMetal, 2026-11-20: `D3DMetal.framework` mapped in `Warframe.x64.exe`)
- [ ] `./uninstall.sh` moves the app to the Trash (skipped for now: needs a throwaway install)
- [x] `./uninstall.sh --delete` removes it
- [x] `./uninstall.sh` refuses an app not built by `install.sh` without `--force`
- [x] Mole clean with the whitelist leaves the running launcher and game data intact

## 4. Open questions

- [ ] Why the launcher installed the game in `C:\windows\Warframe` and not in
      `C:\Program Files\Warframe`, and whether the script should preset the folder.
      Same result on the Mac mini M4, so it is the launcher's default under Wine, not a one-off.
- [ ] Which backend gives the best result, to choose the default.
      So far on the M4 (2026-11-20): DXMT 7.9 ms/frame on the Plains; D3DMetal DX11 11.9 ms (quest mission);
      D3DMetal DX12 23.4 ms on a cold shader cache and 17.6 ms on a warm one. DXMT stays the default for now.
- [x] Can the launcher's DirectX setting be preset by the script? Yes: registry `HKCU\Software\Digital Extremes\Warframe\Launcher`
      `GraphicsAPI` (0 = DirectX 11, 1 = DirectX 12). `install.sh` and `tools/renderer.sh` now set it (2026-11-20).
- [x] **Retina / HiDPI:** on a scaled display (3440×1440 shown as "looks like 1720×720") the game
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
      D3DMetal: fullscreen works but minimizes on every Cmd+Tab (see section 2); DXMT: it loops. Borderless
      works on both, so presetting it looks right.
      Done 2026-11-20: `install.sh` writes a starter `EE.cfg` with Borderless if none exists. Not yet tested on a
      fresh install (the game must accept the partial file and fill in the rest).
- [ ] Is the `+loaddll` Wine debug channel in the template worth turning off for performance?
