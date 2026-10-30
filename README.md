# Bar Volume (`barVolume`) — Dux Shell Plugin

A lightweight background daemon plugin for **[Dux Shell](https://duxlabs.dev)** (`dux-shell >= 2.0.0`) that turns your bar into an instant, customizable system audio and monitor brightness controller on hover — without adding dummy bar widgets or stealing keyboard focus from your active window.

## Features

- **Hover & Scroll Volume Control:** Hover anywhere over your bar (including auto-hiding bars and Dux Island bars) and scroll up/down to adjust system-wide PipeWire volume (`AudioService`), with immediate first-notch response regardless of compositor `mouseScrollFactor`.
- **Control Center Hover Brightness:** Hover over the **Control Center** bar widget and scroll to adjust display brightness (`BrightnessService`) for that bar's monitor (`DDC/CI`, laptop backlight, or per-output software gamma), with configurable target zone (*Entire Control Center*, *Entire Control Center except Mic icon*, or *Brightness icon only*) and step percentage.
- **Live-Fetched Widget Checklist & Per-Bar Customization:**
  - Automatically discovers every active widget configured on your bars (`Empty Bar Space`, `Dux Island`, `Workspace switcher`, `Media`, `Control Center`, `Running apps`, `Clock`, third-party plugin widgets, etc.).
  - Uncheck any widget (e.g., **Media** to keep separate per-player audio scroll, or **Workspace switcher** to keep workspace scroll) while keeping volume control everywhere else.
  - Toggle **Customize Checklist Per Bar** to configure independent widget checklists for each bar (e.g., `Main Bar` vs `Bar 2`).
- **Zero Focus-Stealing Custom Bindings:** Keep default bindings (`Scroll Up/Down` + `Middle Click / M3` mute) or toggle off **Use Default Bindings** to rebind **Volume Up**, **Volume Down**, and **Toggle Mute** via an interactive *"Click or scroll to bind"* recorder (`M3`, `M4/M5`, `M6+`, `Right Click`, scroll directions, and `Ctrl`/`Alt`/`Shift`/`Super` modifiers).
- **Button Press & Hold Repeat:** When actions are bound to mouse buttons, choose between **step + hold repeat**, **step click only**, or **hold repeat only**, with clean `50 ms` / `25 ms`-stepped sliders for **Hold Detection Delay** and **Hold Repeat Interval**.
- **Per-Bar & Per-Display Selection:** Enable across all bars/monitors automatically, or toggle individual `Bar — Display` targets.
- **Configurable Steps, Touchpad, Overdrive & 50ms-Stepped OSD:**
  - **Use Dux Shell Volume Step** by default, or toggle off to reveal a **Custom Volume Step (%)** slider.
  - **Touchpad Scrolling** disabled by default; toggle on to reveal **Touchpad Volume Step (%)** and **Touchpad Scroll Distance (px)** sliders.
  - **OSD Display Time (`300 ms–6000 ms`):** Always available whenever **Show Volume OSD Popup** is enabled, snapping cleanly to `50 ms` increments (hidden automatically if OSD popups are turned off).

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

Open **Dux Shell Settings → Plugins → Bar Volume** to customize volume/brightness steps, per-bar widget checklists, input bindings, hold delays, bars/displays, mute behavior, and OSD popup timing. All changes apply immediately.
