# Bar Volume (`barVolume`)

A lightweight background daemon plugin for **[Dux Shell](https://duxlabs.dev)** (`dux-shell >= 2.0.0`) that turns your bar into an instant, customizable system audio and monitor brightness controller on hover — without adding extra bar widgets or stealing keyboard focus from your active window.

## Features

- **Hover & Scroll Volume Control:** Hover anywhere over your bar (including auto-hiding bars, vertical bars, and Dux Island bars) and scroll up/down to adjust system-wide PipeWire volume (`AudioService`) with immediate first-notch response across compositors (`Niri`, `Hyprland`, `Sway`, `MangoWC`, `DWL`, `KWin`).
- **Control Center Hover Brightness:** Hover over the **Control Center** bar widget and scroll to adjust display brightness (`BrightnessService`) for that bar's monitor (`DDC/CI`, laptop backlight, or per-output software gamma), with configurable target zone (*Entire Control Center*, *Entire Control Center except Mic icon*, or *Brightness icon only*) and step percentage.
- **Live-Fetched Widget Checklist & Per-Bar Customization:**
  - Automatically discovers every active widget configured on your bars (`Empty Bar Space`, `Dux Island`, `Workspace switcher`, `Media`, `Control Center`, `Running apps`, `Clock`, third-party plugin widgets, etc.).
  - Uncheck any widget (for example, **Media** to preserve separate per-player audio scroll, or **Workspace switcher** to preserve workspace switching) while keeping volume scroll active everywhere else.
  - Toggle **Customize Checklist Per Bar** to configure independent widget checklists for each bar (e.g., `Main Bar` vs `Bar 2`).
- **Custom Mouse & Scroll Bindings (Zero Focus Stealing):** Keep default bindings (`Scroll Up/Down` + `Middle Click / M3` mute) or toggle off **Use Default Bindings** to rebind **Volume Up**, **Volume Down**, and **Toggle Mute** via an interactive *"Click or scroll to bind"* recorder (`M3`, `M4/M5`, `M6+`, `Right Click`, scroll directions, and `Ctrl`/`Alt`/`Shift`/`Super` modifiers).
- **Button Press & Hold Repeat:** When volume or brightness actions are bound to mouse buttons, choose between **step + hold repeat**, **step click only**, or **hold repeat only**, with clean `50 ms` / `25 ms`-stepped sliders for **Hold Detection Delay** and **Hold Repeat Interval**.
- **Per-Bar & Per-Display Targeting:** Enable across all bars and monitors automatically, or toggle individual `Bar — Display` targets.
- **Progressive Step, Touchpad, Overdrive & 50ms-Stepped OSD:**
  - **Use Dux Shell Volume Step** by default, or toggle off to set a **Custom Volume Step (%)**.
  - **Touchpad Scrolling** (optional): toggle on to configure **Touchpad Volume Step (%)** and **Touchpad Scroll Distance (px)**.
  - **Custom Max Volume Cap (Overdrive up to 150%):** Syncs cleanly with Dux Shell's native `VolumeOSD` so overdrive percentages above `100%` render accurately.
  - **OSD Display Time (`300 ms–6000 ms`):** Always available when **Show Volume OSD Popup** is enabled, snapping strictly to `50 ms` steps.

## Requirements

- **Dux Shell (`dms`)** `>= 2.0.0`
- **PipeWire / WirePlumber** (via Dux Shell's built-in `AudioService`)
- *(Optional)* Controllable backlight, `DDC/CI`, or software gamma device via Dux Shell's `BrightnessService` for Control Center hover brightness

## Installation

### Via Dux Plugin Registry / Settings UI

Search for **Bar Volume** in **Dux Shell Settings → Plugins → Browse**, or install from the terminal:

```bash
dms plugins install barVolume
dms ipc call plugins enable barVolume
```

### Manual Installation (`git clone`)

```bash
git clone https://github.com/segfawlt/dux-bar-volume.git ~/.config/dms/plugins/barVolume
dms ipc call plugin-scan rescan barVolume
dms ipc call plugins enable barVolume
```

## Configuration

Open **Dux Shell Settings → Plugins → Bar Volume** to customize:

1. **Volume Step & Limits** — System vs. custom step, optional two-finger touchpad scrolling, overdrive cap (`50%–150%`), and scroll direction inversion.
2. **Control Center Hover Brightness** — Toggle per-monitor brightness scroll on Control Center, choose target zone, and set brightness step `%`.
3. **Bar Coverage & Widget Checklist** — One-click presets (*Enable All*, *Keep Media & Workspaces Native*, *Uncheck All*), live widget checklist, and optional per-bar checklists.
4. **Bars & Displays** — Target all bars automatically or toggle specific `Bar — Display` combinations.
5. **Input Bindings & Button Hold** — Interactive mouse/wheel/modifier recorder and rapid-hold repeat timing.
6. **Mute & Feedback** — Behavior when scrolling while muted, native OSD popup toggle + `50 ms`-stepped display time, and volume feedback sound.

All changes take effect immediately without restarting Dux Shell.

## IPC Commands

Bar Volume exposes an IPC target (`barVolume`) for scripts, keybinds, or debugging:

```bash
# Inspect active bar overlays and current effective settings
dms ipc call barVolume status

# Trigger volume / mute actions using Bar Volume's step, cap, and OSD settings
dms ipc call barVolume volumeUp
dms ipc call barVolume volumeDown
dms ipc call barVolume toggleMute
```

## License

Licensed under the [GNU General Public License v3.0 (GPL-3.0)](./LICENSE).
