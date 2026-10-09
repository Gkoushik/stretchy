#!/bin/bash
# Regenerate the README images:
#   docs/demo.gif       animated character doing a few moves
#   docs/exercises.png  every exercise in moves.json at its peak pose
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O -framework AppKit -framework WebKit -o tools/iconrender tools/iconrender.swift
swiftc -O -framework AppKit -o tools/autocrop tools/autocrop.swift
swiftc -O -framework AppKit -framework WebKit -o tools/gifrender tools/gifrender.swift
python3 - <<'PY'
import json
body = open('mochi/stretchy-body.svg.txt').read()
css = open('mochi/stretchy.css').read()
moves = [m for g in json.load(open('moves.json'))['groups'] for m in g['moves']]
cells = []
for m in moves:
    cls = f"mochi peaks {m['key']}" + (" eyes-open" if m.get('eyes') else "")
    label = m['label'].replace(' (bedtime only)', '')
    cells.append(f'<div class="c"><svg class="{cls}" viewBox="215 26 250 294">{body}</svg><b>{label}</b></div>')
open('/tmp/stretchy-readme.html', 'w').write(f'''<!doctype html><html><head><meta charset="utf-8"><style>{css}
html,body{{margin:0;background:transparent;font:600 13px -apple-system,system-ui}}
.g{{display:grid;grid-template-columns:repeat(7,128px);gap:6px 4px;padding:8px}}
.c{{text-align:center;color:#8a8a8a}} svg{{width:128px;height:150px;display:block}}
b{{display:block;margin-top:2px;white-space:nowrap}}</style></head>
<body><div class="g">{''.join(cells)}</div></body></html>''')
PY
./tools/iconrender /tmp/stretchy-readme.html /tmp/stretchy-readme.png 940
./tools/autocrop /tmp/stretchy-readme.png docs/exercises.png

python3 - <<'PY2'
body = open('mochi/stretchy-body.svg.txt').read()
css = open('mochi/stretchy.css').read()
open('/tmp/stretchy-gif.html', 'w').write(f'''<!doctype html><html><head><meta charset="utf-8"><style>{css}
html,body{{margin:0;height:100%;background:#FFF4EA;overflow:hidden}}
svg.mochi{{width:100%;height:100%;display:block}}
.mochi.fr *{{animation-play-state:paused!important;animation-delay:var(--t)!important}}
</style></head><body>
<svg class="mochi fr" id="m" viewBox="215 26 250 294" preserveAspectRatio="xMidYMid meet">{body}</svg>
<script>
// Each move plays one full cycle. STEP is animation seconds per frame.
const MOVES = [["turn",6],["tilt",6],["shrug",3],["reach",6],["side",6],["cross",6]];
const STEP = 0.125;
const FRAMES = [];
for (const [k, c] of MOVES) for (let t = 0; t < c - 1e-9; t += STEP) FRAMES.push([k, t]);
const svg = document.getElementById('m');
window.frameCount = () => FRAMES.length;
window.showFrame = i => {{
  const [k, t] = FRAMES[i];
  svg.setAttribute('class', 'mochi fr ' + k);
  svg.style.setProperty('--t', (-t) + 's');
  void svg.getBoundingClientRect();
}};
</script></body></html>''')
PY2
./tools/gifrender /tmp/stretchy-gif.html docs/demo.gif 255 300 300 0.09
echo "==> Done: docs/demo.gif, docs/exercises.png"
