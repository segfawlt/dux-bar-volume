# Bar Volume Control

Control the system volume and monitor brightness by scrolling over any [Dux Shell](https://duxlabs.dev) bar (`dux-shell >= 2.0.0`).
![Bar Volume Control Settings](./assets/preview.png)

## Note
This is the plugin I use daily, so it won't be abandoned. If you see long gaps between commits, it just means everything is working smoothly. PRs are very welcome! 

Note: 100% code generated with AI. I always do quick inspection before shipping, but can't guarantee code quality (it won't be too bad, don't worry).

## Features

- **Scroll volume**: Adjust system volume by scrolling anywhere over the bar (supports horizontal, vertical, auto-hide, and Dux Island bars).
- **Middle click to mute**: Middle click over the bar to mute or unmute system audio.
- **Control Center brightness**: Scroll over the Control Center bar widget to change monitor brightness (`DDC/CI`, laptop backlight, or software gamma).
- **Scroll area & widget checklist**: Live checklist of every widget on your bars — uncheck individual widgets (such as **Media** or **Workspace switcher**) to keep their native scroll behavior, shared across bars or customized per bar.
- **Custom input bindings**: Rebind volume up, volume down, and toggle mute to any mouse button (`M3`, `M4/M5`, `M6+`, right click), wheel direction, or modifier combination (`Ctrl`, `Alt`, `Shift`, `Super`), with optional press-and-hold repeat.
- **Steps, touchpad & OSD**: Follow Dux Shell's volume step or set a custom step, enable optional two-finger touchpad scrolling, set a custom max volume cap (up to `150%`), and customize OSD popup duration (`50 ms` increments).

## Installation

### Via Dux Plugin Registry / Settings UI (Not yet)
This section is made for future integration. I have not made PR for this plugin yet, so for now you cannot install or browse the plugin directly from DMS

Search for **Bar Volume Control** in **Dux Shell Settings → Plugins → Browse**, or install from the terminal:

```bash
dms plugins install barVolume
dms ipc call plugins enable barVolume
```

### Manual Installation (The only method currnetly)

```bash
git clone https://github.com/segfawlt/dux-bar-volume.git ~/.config/dms/plugins/barVolume
dms ipc call plugin-scan rescan barVolume
dms ipc call plugins enable barVolume
```

## Configuration

Open **Dux Shell Settings → Plugins → Bar Volume Control** to configure volume and brightness steps, per-bar widget checklists, target bars/displays, custom mouse/modifier bindings, and OSD popup timing. Changes take effect immediately.

## IPC Commands

```bash
dms ipc call barVolume status
dms ipc call barVolume volumeUp
dms ipc call barVolume volumeDown
dms ipc call barVolume toggleMute
```

## License

Published under the [GNU General Public License v3.0 (GPL-3.0)](./LICENSE).
