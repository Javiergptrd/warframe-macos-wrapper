# Changelog

## [Unreleased] — 0.1.0

### Added
- `install.sh`: builds `Warframe.app` from Sikarugir template 1.0.27 and the
  CrossOver 24.0.7-based engine `WS12WineCX24.0.7_7` (pinned, SHA-256 verified),
  creates the Wine prefix, installs the official Warframe launcher silently and sets
  the app to open it. Options: `--name`, `--dir`, `--msi`, `--renderer`,
  `--skip-installer`, `--launch`, `--yes`.
- `tools/renderer.sh`: switch between DXMT and D3DMetal.
- `tools/status.sh`: engine, backend, game data size and launcher log.
- `uninstall.sh`: moves the app to the Trash (or `--delete`), optional cache purge.
- Mole whitelist integration so cleanups never touch the wrapper or Wine's temp files.
- Documentation: README (English and Spanish), how it works, testing checklist,
  third-party notices.
