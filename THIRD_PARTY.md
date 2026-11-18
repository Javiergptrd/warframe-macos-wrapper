# Third-party components

This repository contains only original scripts and documentation (MIT, see `LICENSE`).
None of the components below are stored here. `install.sh` downloads them from
their authors at install time, on the user's own Mac.

| Component | Author | License | How it is obtained |
|---|---|---|---|
| Wine | The Wine project | LGPL-2.1-or-later | Part of the engine below |
| CrossOver open-source tree (24.0.7) | CodeWeavers | LGPL-2.1-or-later (Wine parts); sources at <https://www.codeweavers.com/crossover/source> | The engine below is built from it |
| Sikarugir template `Template-1.0.27` and engine `WS12WineCX24.0.7_7` | Sikarugir project (Gcenx and contributors) | No license file published in their repositories | Downloaded from <https://github.com/Sikarugir-App/Template> and <https://github.com/Sikarugir-App/Engines> releases |
| DXMT | 3Shain | See <https://github.com/3Shain/dxmt> | Bundled in the Sikarugir template |
| MoltenVK | Khronos Group | Apache-2.0 | Bundled in the Sikarugir template |
| D3DMetal | Apple Inc. | Apple license (Game Porting Toolkit); not for commercial ports | Bundled in the Sikarugir template; only enabled by the user |
| Warframe, its installer and launcher | Digital Extremes Ltd. | Proprietary; Warframe is a trademark of Digital Extremes | Downloaded from `content.warframe.com` and the official launcher |

## Optional integrations

| Tool | Author | License | How it is used |
|---|---|---|---|
| Mole | tw93 | GPL-3.0 | Not downloaded. If it is already installed, `install.sh` adds the wrapper's paths to its cleanup whitelist |

## Tools used to make this project

| Tool | Author | Use |
|---|---|---|
| Claude Code | Anthropic | AI coding assistant used to write and test the scripts and documentation, directed by the maintainer |

This project is not affiliated with any of the parties above.
