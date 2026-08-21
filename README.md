# Game Launcher — Omarchy Plugin

A bar widget plugin for [Omarchy](https://omarchy.org) that unifies your game library across **Steam**, **Lutris**, **Heroic** (Epic/GOG/Amazon), **Bottles**, and **Flatpak** into a single searchable launcher panel.

## Features

- Unified game list aggregated from all supported launchers
- Deduplicates games that appear in multiple launchers
- Sorts by recently played, then alphabetically
- Live search/filter inside the panel
- Bar widget shows total game count
- Filters out Steam runtime/redistributable entries

## Supported Launchers

| Launcher | Source |
|----------|--------|
| Steam | `libraryfolders.vdf` + `.acf` files |
| Lutris | Lutris SQLite/JSON library |
| Heroic | Epic, GOG, Amazon libraries |
| Bottles | `bottles.yml` installed programs |
| Flatpak | Installed Flatpak apps |

## Installation

Copy (or clone) this folder into your omarchy plugins directory:

```sh
git clone https://github.com/sir-francisdrake/game-launcher.git \
  ~/.config/omarchy/plugins/io.github.sir-francisdrake.game-launcher
```

Then enable the **Game Launcher** bar widget from Omarchy settings.

## Files

- `manifest.json` — plugin metadata and entry points
- `BarWidget.qml` — bar widget showing the game count
- `Panel.qml` — launcher panel UI with search and game grid
- `Model.js` — parsing/merging logic for each launcher's data format

## License

MIT
