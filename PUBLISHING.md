# Maintainer Notes — Publishing to the Omarchy Plugins Site

How to list this plugin on [omarchyplugins.com](https://omarchyplugins.com), the
community directory of Omarchy shell plugins.

## Repository requirements (marketplace checklist)

- [x] Public GitHub repository — `sir-francisdrake/game-launcher`
- [x] Valid `manifest.json` in the repository root
- [x] README with install instructions
- [x] LICENSE file (MIT)
- [ ] Optional: `preview.png` screenshot of the panel (optimized automatically by the marketplace)

## Pre-submission checks

Run these from a checkout of the repo before every submission or release:

```sh
# 1. Manifest + layout validation (same checks the shell runs at load time)
omarchy plugin validate ~/.config/omarchy/plugins/io.github.sir-francisdrake.game-launcher

# 2. Plugin is discovered and enabled
omarchy plugin list --json | jq '.[] | select(.id == "io.github.sir-francisdrake.game-launcher")'

# 3. Panel opens/closes over IPC
omarchy-shell shell summon io.github.sir-francisdrake.game-launcher '{}'
omarchy-shell shell hide io.github.sir-francisdrake.game-launcher
```

If the plugin validates but is not listed, force a rescan:
`omarchy-shell shell rescanPlugins`.

## Submitting

1. Open the submission issue form:
   https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml
2. Fill in:
   - **Repository**: `https://github.com/sir-francisdrake/game-launcher`
   - **Plugin ID**: `io.github.sir-francisdrake.game-launcher`
   - **Category**: Gaming
   - **Tags**: games, steam, lutris, heroic, bottles, flatpak, launcher, bar-widget
3. Automated validation runs against the current commit of `main`, so make sure
   the branch is clean and pushed before submitting.
4. A marketplace maintainer approves the listing after validation passes.

## Release checklist

- Bump `version` in `manifest.json` (semver)
- Update the README if launcher support or settings changed
- Run the pre-submission checks above
- Commit and push to `main`
- If already listed, comment on the original submission issue so the
  marketplace re-validates the new commit

## Gotchas learned the hard way

- The plugin `id`, folder name under `~/.config/omarchy/plugins/`, and every
  internal `moduleName` / IPC target must all match. Renaming only the manifest
  ID makes the widget disappear from the bar until `shell.json` and the QML
  files are updated too.
- The ID namespace `omarchy.*` is reserved for first-party plugins; third-party
  IDs follow `io.github.<user>.<name>`.
- Users install with:
  ```sh
  omarchy plugin add https://github.com/sir-francisdrake/game-launcher.git --enable
  ```
