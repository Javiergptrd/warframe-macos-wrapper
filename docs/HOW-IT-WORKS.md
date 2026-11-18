# How it works

This is the process `install.sh` automates. It was first done by hand on
2026-11-18 (MacBook Pro M2 Pro, macOS 27.2) and then turned into the script.

## The pieces

| Layer | What it is | Why it is needed |
|---|---|---|
| Rosetta 2 | Apple's x86-64 translator | The Wine engine and Warframe are Intel (x86-64) code |
| Wine engine `WS12WineCX24.0.7_7` | Wine built by Sikarugir from CodeWeavers' open-source CrossOver 24.0.7 tree | Runs Windows programs on macOS |
| Sikarugir template `1.0.27` | An `.app` shell (formerly Wineskin) with a launcher, settings in `Info.plist`, and graphics translators | Turns a Wine prefix into a normal Mac app |
| DXMT | Open-source DirectX 10/11 → Metal translator | Warframe draws with DirectX 11 |
| D3DMetal | Apple's DirectX 11/12 → Metal translator (from the Game Porting Toolkit) | Optional; enables DirectX 12 |
| Warframe launcher | `Launcher.exe` from Digital Extremes | Downloads and updates the game |

The open-source CrossOver release does not include D3DMetal (Apple's) or CrossOver's
own packaging. That is why the engine is combined with Sikarugir's template instead
of compiling CrossOver from source: Sikarugir already publishes engines built from
that exact source, plus the DXMT and D3DMetal integration.

## Steps

1. **Check the Mac.** macOS ≥ 14.6, Rosetta 2 installed, free disk space, and no
   existing app with the same name.
2. **Download** the template and engine into
   `~/Library/Application Support/Sikarugir/{Template,Engines}`, the same cache
   Sikarugir Creator uses. Each file is checked against a pinned SHA-256 that matches
   the digest GitHub publishes for the release asset.
3. **Assemble the app.** Extract the template (`Template-1.0.27.app`), extract the
   engine (`wswine.bundle`), move the engine to `Contents/SharedSupport/wine`, move the
   app to `~/Applications/Sikarugir/Warframe.app`, and set `CFBundleName`. Sikarugir's
   launcher assigns its own `CFBundleIdentifier` on first run (`com.sikarugir.<Name><n>`).
   The marker keys `WFWVersion` and `WFWEngine` are added so the other scripts can
   recognize apps built by this project.
4. **Create the Windows environment:**
   `Contents/MacOS/wineskinlauncher WSS-wineprefixcreate` (about 1.5 minutes). The
   template renames the default `crossover` Windows user to `Sikarugir`.
5. **Install Warframe.** The official `Warframe.msi` is downloaded from
   `content.warframe.com` (or given with `--msi`). It is checked with `file`: it must be
   an MSI whose author is Digital Extremes. It is copied to `C:\` and installed silently:

   ```bash
   WINEPREFIX=…/prefix DYLD_FALLBACK_LIBRARY_PATH=…/Contents/Frameworks \
     …/wine/bin/wine msiexec /i 'C:\Warframe.msi' /qn '/l*v' 'C:\warframe-msi.log'
   …/wine/bin/wineserver -w
   ```

   The installer starts `Launcher.exe`, which updates itself (about 700 MB) before
   exiting, so the wait takes a few minutes. Success is the line
   `Action ended …: INSTALL. Return value 1.` in the MSI log.
6. **Configure.** `Program Name and Path` in `Info.plist` points to
   `/users/Sikarugir/AppData/Local/Warframe/Downloaded/Public/Tools/Launcher.exe`, so
   opening the app opens the launcher. The graphics backend is chosen with the
   `D3DMETAL` and `DXVK` keys (both `0` means DXMT). Mole exclusions are added when
   relevant.

On first launch, the launcher asks for the install folder and downloads the game
(tens of GB) into the prefix.

## Layout inside the app

```
Warframe.app/Contents/
├── Info.plist                    settings: program path, graphics backend, Wine options
├── MacOS/wineskinlauncher        Sikarugir launcher (WSS-* commands)
├── Frameworks/                   MoltenVK, Vulkan loader, helper libraries
├── Configure.app                 Sikarugir's settings tool
├── drive_c → SharedSupport/prefix/drive_c
└── SharedSupport/
    ├── wine/                     the CrossOver-based engine
    ├── renderer/{dxmt,d3dmetal,dxvk,…}
    ├── prefix/                   the Windows environment (C: drive, registry)
    └── Logs/                     wfw-install.log, warframe-msi.log
```

Logs worth knowing:

- `Contents/SharedSupport/Logs/wfw-install.log`: the script's own log.
- `Contents/SharedSupport/Logs/warframe-msi.log`: the Warframe installer log.
- `…/prefix/drive_c/users/Sikarugir/AppData/Local/Warframe/Launcher.log`: the launcher
  log, including download progress.

## Running Wine by hand

The engine's binaries load libraries from the template, so set both variables:

```bash
APP=~/Applications/Sikarugir/Warframe.app/Contents
export WINEPREFIX="$APP/SharedSupport/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Frameworks:/usr/lib"
"$APP/SharedSupport/wine/bin/wine" winecfg
"$APP/SharedSupport/wine/bin/wineserver" -k     # stop everything in this prefix
```

Sikarugir's launcher also accepts `WSS-winecfg`, `WSS-regedit`, `WSS-cmd`,
`WSS-taskmgr` and `WSS-wineserverkill`.

## Known notes

- With DXMT (DirectX 11) there is no persistent shader cache, so the first runs stutter.
- On this test Mac the launcher put the game in `C:\windows\Warframe\Downloaded\Public`,
  not in the proposed `C:\Program Files\Warframe`. Still under investigation (see TESTING.md).
- Apple has said Rosetta 2 stays fully available through macOS 27, with limited support
  for older games afterwards. Future macOS versions may affect this approach.
