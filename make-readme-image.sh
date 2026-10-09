#!/bin/bash
# Regenerate docs/exercises.png: every exercise in moves.json at its peak pose.
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O -framework AppKit -framework WebKit -o tools/iconrender tools/iconrender.swift
swiftc -O -framework AppKit -o tools/autocrop tools/autocrop.swift
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
echo "==> Done: docs/exercises.png"
