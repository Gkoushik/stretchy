<p align="center">
  <img src="docs/icon.png" width="128" alt="Stretchy icon">
</p>

<h1 align="center">Stretchy</h1>

<p align="center">A tiny macOS menu bar app that nudges you to move. Every so often a friendly character slides in from the top-right, performs one stretch, then tucks away until the next break.</p>

---

## Why

Sitting at a computer all day is rough on your neck, shoulders, and eyes. Stretchy keeps you active with short, low-friction movement breaks: one exercise at a time, on a schedule you set, then it gets out of your way.

## Features

- **Menu bar only** — no Dock icon, no window in your face. Just the character in the menu bar.
- **Scheduled breaks** — the character pops up every N minutes (1 min for testing, up to 2 hours).
- **One exercise per break** — slides in from the right, animates the stretch, auto-hides after a set duration.
- **12 built-in exercises** across Eyes, Neck, Shoulders, and Full body.
- **Custom routine** — a drag-to-reorder editor to pick which exercises run, in what order. Add, remove, reorder.
- **In order or shuffle.**
- **Three sizes** — Small, Medium, Large.
- **Stop button** — dismiss the current exercise early (× on the popup, or a menu item).
- **Live countdown** — the menu shows the time until the next exercise.
- Settings persist across restarts.

## Requirements

- macOS 13 or later
- Xcode command line tools (`swiftc`, `iconutil`, `sips`) — install with `xcode-select --install`

No third-party package managers. The app is pure Swift (AppKit + SwiftUI + WebKit), built with a shell script.

## Build & run

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

### Install permanently

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
| **Stop current exercise** | Dismiss the current popup (enabled only while one is showing). |
| **Edit routine…** | Open the drag-to-reorder routine editor. |
| **Show every…** | Interval between breaks (1 min / 15 / 30 / 45 min / 1 h / 2 h). |
| **Show for…** | How long the character stays visible (15 s / 30 s / 1 min / 2 min). |
| **Exercise order** | In order or shuffle. |
| **Size** | Small / Medium / Large. |
| **Quit** | Quit Stretchy. |

## Customizing exercises

The exercise catalogue lives in [`moves.json`](moves.json):

```json
{
  "groups": [
    { "name": "Neck", "moves": [
      { "key": "roll", "label": "Neck roll" }
    ]}
  ]
}
```

- **`label`** — free text shown in the menu and routine editor.
- **`key`** — must match an animation defined in `mochi/mochi.css`. Available keys:
  `ecirc`, `eud`, `elr`, `turn`, `tilt`, `roll`, `shrug`, `circles`, `cross`, `reach`, `side`, `yawn`.

Edit `moves.json`, then `./build.sh` to pick up the changes. Reordering and relabeling is safe; a brand-new key needs a matching SVG/CSS animation in the Mochi asset.

## How it works

- The character is a self-contained **SVG + CSS animation** (the "Mochi" asset set). The app renders it in a transparent, borderless `WKWebView` floating panel.
- Swift drives which move plays via `webView.evaluateJavaScript("setMove('roll', false)")`.
- A repeating `Timer` triggers each break; the panel slides in and out with `NSAnimationContext`.
- The routine is stored in `UserDefaults`.

## Project structure

```
.
├── Sources/main.swift     # the whole app (AppKit + SwiftUI + WebKit)
├── build.sh               # compile + assemble Stretchy.app
├── make-icons.sh          # regenerate Stretchy.icns + menubar.png from SVG
├── moves.json             # exercise catalogue (editable)
├── mochi/                 # Mochi character assets (SVG + CSS)
│   ├── mochi.css
│   ├── mochi-body.svg.txt
│   └── svg/               # per-move standalone animated SVGs
├── tools/iconrender.swift # offscreen WebKit SVG → PNG renderer
├── Stretchy.icns          # app icon (committed)
└── menubar.png            # menu bar face (committed)
```

## Credits

Character animations are the **Mochi stretch animation** asset set (pure SVG + CSS, 12 moves). See `mochi/` for the original CSS and SVG.

## License

[MIT](LICENSE)
