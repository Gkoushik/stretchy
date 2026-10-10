<p align="center">
  <img src="docs/demo.gif" width="200" alt="Stretchy character doing neck, shoulder and full-body stretches">
</p>

<h1 align="center">Stretchy</h1>

<p align="center">A tiny macOS menu bar app that nudges you to move. Every so often a friendly character slides in from the top-right, performs one stretch, then tucks away until the next break.</p>

---

## Exercises

<p align="center">
  <img src="docs/exercises.png" alt="All Stretchy exercises at their peak pose">
</p>

## Why

Sitting at a computer all day is rough on your neck, shoulders, and eyes. Stretchy keeps you active with short, low-friction movement breaks: one exercise at a time, on a schedule you set, then it gets out of your way.

## Features

- **Menu bar only** — no Dock icon, no window in your face. Just the character in the menu bar.
- **Scheduled breaks** — the character pops up every N minutes (1 min for testing, up to 2 hours).
- **One exercise per break**: the character slides in at the top-right corner, does the stretch, then slides away. No text, no buttons, and clicks pass straight through it.
- **13 built-in exercises** across Eyes, Neck, Shoulders, and Full body, including a 20-20-20 "look far away" eye rest.
- **Stretchy arms**: reach, side bend and cross-body pull stretch the arms to length instead of rotating stiff limbs.
- **Template menu bar icon** that adapts to light and dark menu bars. It fills up from the bottom as the next break approaches, and turns into the colored character only while a break is showing.
- **Accessibility**: with Reduce Motion on, each exercise shows a still of its peak pose and the character fades instead of sliding. VoiceOver announces each break without taking focus.
- **Custom routine** — a drag-to-reorder editor to pick which exercises run, in what order. Add, remove, reorder.
- **In order or shuffle.**
- **Three sizes** — Small, Medium, Large.
- **Live countdown** — the menu shows the time until the next exercise.
- Settings persist across restarts.

## Install

1. Download **Stretchy-x.y.z.dmg** from the [latest release](https://github.com/Gkoushik/stretchy/releases/latest).
2. Open the DMG and drag **Stretchy** into **Applications**.
3. Open Stretchy from Applications. The character appears in your menu bar.

Runs on macOS 13 or later, on both Apple Silicon and Intel Macs.

**First launch:** Stretchy isn't notarized by Apple, so macOS blocks it the first time with a message that it "cannot be opened" or "cannot be verified". To allow it once:

- Open **System Settings → Privacy & Security**, scroll to the message about Stretchy, and click **Open Anyway**. Or:
- Run this in Terminal, then open the app normally:
  ```bash
  xattr -dr com.apple.quarantine /Applications/Stretchy.app
  ```

To start Stretchy automatically, add it under **System Settings → General → Login Items**.

## Build from source

### Requirements

- macOS 13 or later
- Xcode command line tools (`swiftc`, `iconutil`, `sips`) — install with `xcode-select --install`

No third-party package managers. The app is pure Swift (AppKit + SwiftUI + WebKit), built with a shell script.

### Build & run

```bash
./build.sh
open Stretchy.app
```

`build.sh` compiles `Sources/main.swift`, assembles `player.html` (the animated character) and copies assets into a self-contained `Stretchy.app` bundle, then ad-hoc code-signs it.

To regenerate the app icon and menu bar image from the Mochi SVG assets:

```bash
./make-icons.sh
```

(The committed `Stretchy.icns` and `menubar.png` already cover a normal build, so you only need this if you change the character or colors.)

### Install your own build

```bash
cp -R Stretchy.app /Applications/
```

Then add it to **System Settings → General → Login Items** to launch at startup.

## Usage

Click the character in the menu bar:

| Item | What it does |
|---|---|
| **Next exercise in M:SS** | Live countdown to the next break (updates while the menu is open). |
| **Stretch now** | Trigger a break immediately. |
| **Stop current exercise** | Hide the character early (enabled only while it is showing). |
| **Edit routine…** | Open the drag-to-reorder routine editor. |
| **Show every…** | Interval between breaks (1 min / 15 / 30 / 45 min / 1 h / 2 h). |
| **Show for…** | How long the character stays visible (15 s / 30 s / 1 min / 2 min). |
| **Exercise order** | In order or shuffle. |
| **Bedtime yawn** | The big yawn is night-only. Turn it on or off, pick a start time (9 PM to 12 AM, default 10 PM) and how often it repeats (15 min, 30 min or 1 hour, default 15 min). It runs until 6 AM and never appears in the daytime rotation. |
| **Size** | Small / Medium / Large. |
| **Quit** | Quit Stretchy. |

## Customizing exercises

The exercise catalogue lives in [`moves.json`](moves.json):

```json
{ "key": "tilt", "label": "Ear to shoulder", "detail": "15s each side, shoulders down",
  "type": "hold", "cycle": 6, "sides": ["Left", "Right"] }
```

| Field | Meaning |
|---|---|
| `key` | Animation in `mochi/stretchy.css`: `ecirc`, `eud`, `elr`, `far`, `turn`, `tilt`, `roll`, `shrug`, `circles`, `cross`, `reach`, `side`, `yawn`. |
| `label` | Name in the routine editor and the VoiceOver announcement. |
| `detail` | Short instruction read out by VoiceOver. |
| `type` | `hold`, `reps` or `flow`. |
| `cycle` | Seconds per animation loop (6 for holds, 3 or 4 for reps). |
| `sides` | Two labels shown in the side chip, from the viewer's side (copy the character like a mirror). |
| `reps` | Number of dots in the rep counter. |
| `eyes` | `true` zooms to the face and shows the target dot for the eyes to follow. |

Edit `moves.json`, then `./build.sh` to pick up the changes. Reordering and relabeling is safe; a brand-new key needs a matching SVG/CSS animation in the Mochi asset.

## How it works

- The character is an **SVG + CSS animation**. `mochi/stretchy-body.svg.txt` is a fork of the Mochi body with attached shoulders (a trapezius that rises with the shrug), wrapper groups so circles can be built from two sine waves a quarter period apart, and a target dot for eye moves. `mochi/stretchy.css` holds all motion on a shared timing system (6s holds, 3 to 4s reps, one easing pair).
- `build.sh` inlines the CSS and body into `web/player.html`, rendered in a transparent `WKWebView` inside a click-through panel that never takes focus.
- Swift passes the move to the page with `setMove({key, eyes})`.
- A repeating `Timer` triggers each break. The character slides in from the right edge; with Reduce Motion it fades instead.
- The routine is stored in `UserDefaults`.

## Project structure

```
.
├── Sources/main.swift     # the whole app (AppKit + SwiftUI + WebKit)
├── build.sh               # compile (universal) + assemble Stretchy.app
├── make-release.sh        # build the release DMG into dist/
├── make-icons.sh          # regenerate Stretchy.icns + menubar.png from SVG
├── make-readme-image.sh   # regenerate docs/demo.gif and docs/exercises.png
├── moves.json             # exercise catalogue (editable)
├── web/player.html        # character page template
├── mochi/
│   ├── stretchy.css       # Stretchy motion system (used by the app)
│   ├── stretchy-body.svg.txt  # forked character rig (used by the app)
│   ├── mochi.css          # original Mochi asset, kept for reference
│   ├── mochi-body.svg.txt # original Mochi asset, kept for reference
│   └── svg/               # original per-move standalone SVGs
├── tools/iconrender.swift # offscreen WebKit SVG → PNG renderer
├── Stretchy.icns          # app icon (committed)
└── menubar.png            # menu bar face (committed)
```

## Credits

Character animations are the **Mochi stretch animation** asset set (pure SVG + CSS, 12 moves). See `mochi/` for the original CSS and SVG.

## License

[MIT](LICENSE)
