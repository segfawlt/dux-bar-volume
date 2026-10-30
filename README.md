# Bar Volume (`barVolume`) — Dux Shell Plugin

A lightweight background daemon plugin for **[Dux Shell](https://duxlabs.dev)** (`dux-shell >= 2.0.0`) that turns your bar into an instant, customizable system audio controller on hover — without adding dummy bar widgets or stealing keyboard focus from your active window.

## Features

- **Hover & Scroll Volume Control:** Hover anywhere over your bar (including auto-hiding bars) and scroll up/down to adjust system-wide PipeWire volume (`AudioService`).
- **System-Wide Media Override:** Scrolling over the Media (`music`) widget adjusts **system audio** by default instead of per-player MPRIS volume (toggleable in settings).
- **Zero Focus-Stealing Custom Bindings:** Rebind **Volume Up**, **Volume Down**, and **Toggle Mute** via an interactive *"Click or scroll to bind"* recorder in Settings:
  - Scroll directions (`Scroll Up`, `Scroll Down`, `Scroll Left`, `Scroll Right`)
  - Mouse buttons (`Middle Click / M3`, `Side Back / M4`, `Side Forward / M5`, `Extra Buttons M6+`, `Right Click`)
  - Optional modifier combinations (`Ctrl`, `Alt`, `Shift`, `Super` + Scroll/Click)
- **Button Press & Hold Repeat:** When Volume Up/Down is bound to mouse buttons (such as `M4` / `M5`), choose between **step + hold repeat**, **step click only**, or **hold repeat only**, with independent sliders for **Hold Detection Delay (ms)** and **Hold Repeat Interval (ms)**.
- **Per-Bar & Per-Display Selection:** Enable across all bars/monitors automatically, or toggle individual `Bar — Display` targets.
- **Granular Widget Exceptions:** Optionally keep native scroll on `Workspace Switcher`, `Control Center` Mic/Brightness sub-icons, or `Media` player, or restrict actions to `Control Center & Media Widgets Only`.
- **Configurable Steps, Overdrive & Feedback:** Direct sliders for **Volume Step (%)**, **Touchpad Smooth Step (%)**, optional **Max Volume Overdrive Cap (up to 150%)**, **Mute-on-scroll behavior**, **Volume OSD toggle**, and **Volume sound feedback**.

## Installation

### Local / Development Setup

```bash
ln -s ~/Projects/dux-bar-volume ~/.config/dms/plugins/barVolume
dms ipc call plugins enable barVolume
```

To hot-reload after making changes:

```bash
dms ipc call plugins reload barVolume
```

## Configuration

Open **Dux Shell Settings → Plugins → Bar Volume** to customize steps, bindings, hold delays, bars/displays, widget pass-throughs, mute behavior, and OSD feedback. All changes apply immediately.
