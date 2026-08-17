# AGENTS.md

This folder is a live-installed Omarchy shell plugin. Installed plugins live at
`~/.config/omarchy/plugins/<id>/`; this directory is the installed checkout, so
changes here take effect on the next shell reload.

## Plugin essentials

- A valid plugin is one folder with `manifest.json` at its root. Required fields: `schemaVersion` (JSON number `1`, not the string), `id`, `name`, `version`, `kinds` (non-empty array), `entryPoints` (object).
- `id` must be namespaced (e.g. `tariq.alienware-rgb`), ASCII letters/digits/`.`/`_`/`-` only, no `/`, no `..`, no reserved `omarchy.*`.
- Validate before shipping: `omarchy plugin validate .` (from this folder). The validator rejects symlinks anywhere in the plugin.
- `entryPoints` paths must be relative, stay inside the folder, and point to existing files.
- No symlinks, install hooks, post-install scripts, or privileged setup.

## QML conventions

- Entry points are `Item`-based components, not `ShellRoot`s. Kinds: `bar-widget`, `panel`, `overlay`, `menu`, `service`, `bar`.
- A headless background service (`kinds: ["service"]`, `keepLoaded: true`) is the preferred place for always-on behavior like device control.
- The host injects properties (`omarchyPath`, `shell`, `manifest`, `pluginRegistry`, `barWidgetRegistry`, `service`) after load; do not mark them `required`.

## This plugin (Alienfx)

- Manifest id, folder name, and widget `moduleName`/`ipcTarget` are all `tariq.alienfx`. Service (`Service.qml`) wraps `/usr/local/bin/alienware-cli`; BarWidget (`BarWidget.qml`) reaches it via `bar.shell.serviceFor(moduleName)`. `serviceFor` is not reactive to service creation, so the widget must tolerate a null `activity` at load and retry (via `onActivityChanged` + `Component.onCompleted` → `syncFromSetting`). `onSettingsChanged` also re-syncs so edits from the bar settings form apply live.
- Extra components: `AlienHeadIcon.qml` (Canvas-drawn head in `bar.foreground`, zone colors as eyes) and `ColorWheel.qml` (Canvas HS disc + `PanelSlider` brightness; emits `colorPicked(string hex)` on change and `interactionEnded()` on release). Do NOT declare a signal named `colorChanged` — it collides with the `color` property's change signal.
- Colors flow as 24-bit hex (`#rrggbb`); the service converts to the CLI's 0–15 scale per channel via `hexToRgb`. Preset state is `activePreset`; mixing sets it to `"Custom"` and the widget persists `preset` + `customColor` inline in `shell.json`.
- CLI quirks: writes take space-separated `"R G B"` on a 0–15 scale per channel (NOT comma/hex). Writes return exit code 0 even on permission failure — detect by scanning output for `"do you need sudo"` / `"permission"` / `"no alienware LED unit"`. Reads: `alienware-cli -jl` → `{"leds":{"exists":true,"head":{"red":..,"green":..,"blue":..},"left":{..}}}`. Set both zones in one call: `alienware-cli -H "15 0 0" -L "0 0 15"`.
- Writes need no sudo only because of `/etc/udev/rules.d/90-alienware-rgb.rules` (chmods 0666 the sysfs controls on driver add). Without it, writes fail with "do you need sudo". Re-apply with `/tmp/opencode/setup-alienware-perms.sh` after a kernel/driver change (uses `udevadm trigger --action=add`).
- Direct sysfs fallback (if CLI ever misbehaves): `/sys/devices/platform/alienware-wmi/rgb_zones/zone00` (head), `zone01` (left); color is 24-bit hex (`ff0000`), kernel masks to 4 bits/channel; `lighting_control_state` must be `running`; brightness at `/sys/class/leds/alienware::global_brightness/brightness`.

## Live-editing gotchas

- `inotifywait` is NOT installed, so the shell's plugin file watcher does not run — plugin file edits are not auto-reloaded, and `omarchy-shell shell rescanPlugins` can silently serve stale components. The reliable reload after editing plugin files is `omarchy-restart-shell`.
- `omarchy plugin enable <id> --section <s>` only fires the service sync; widget/panel sync needs a full shell reload.

## Reference

Full manifest/schema/kinds reference: `../b.okomart/docs/plugin-structure-and-manifest.md` (sibling checkout). When unsure whether a manifest field or feature is supported, inspect the Omarchy shell source or run `omarchy plugin validate` rather than guessing.