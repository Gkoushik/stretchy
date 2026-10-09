# Design Deep-Dive Prompt — Stretchy

Copy everything below the line into an AI assistant (ChatGPT, Claude, etc.). If the assistant can read a repo, point it at `https://github.com/Gkoushik/stretchy` and the `mochi/svg/` assets, `Stretchy.icns`, `menubar.png`, and `moves.json`. If it cannot, paste the relevant SVGs and the exercise list, or attach `docs/icon.png`.

---

You are a senior product designer and visual-identity critic. I want a rigorous, opinionated deep-dive on the **design language** of a small macOS menu bar app called **Stretchy**, then concrete, prioritized ideas to improve it. Do not be polite for its own sake. Tell me what is weak and why, with specific fixes.

## What Stretchy is

A menu bar-only macOS app that reminds you to move. On a schedule, a small cartoon character ("Mochi") slides in from the top-right corner, performs ONE stretch animation (e.g. neck roll), then auto-hides until the next break. The goal is to keep a desk worker active all day with low-friction, glanceable movement nudges.

Key surfaces:
- **App icon** — a rounded-square (squircle) with a purple-to-violet gradient (`#6E7BF2 → #9A4FD0`) and Mochi's round face centered, open eyes, blush cheeks.
- **Menu bar icon** — Mochi's face only, no background, ~18pt.
- **The character popup** — Mochi (head, neck, shoulders, arms) animated with SVG + CSS. 12 moves grouped as Eyes / Neck / Shoulders / Full body.
- **The exercises themselves** — the vocabulary of motions and how clearly each reads as the stretch it represents.

The 12 exercises (key → label → group):
- `ecirc` Eye circles (Eyes), `eud` Look up and down (Eyes), `elr` Look side to side (Eyes)
- `turn` Head turn (Neck), `tilt` Ear to shoulder (Neck), `roll` Neck roll (Neck)
- `shrug` Shrug (Shoulders), `circles` Shoulder rolls (Shoulders), `cross` Cross-body pull (Shoulders)
- `reach` Reach up (Full body), `side` Side bend (Full body), `yawn` Big yawn (Full body)

## What I want you to evaluate

### 1. Icon design language
- Does the icon read clearly at **16px, 32px, and 1024px**? What breaks at small sizes?
- Is it coherent with macOS icon conventions (shape, depth, padding, how it sits next to Apple's own icons) while still distinctive?
- Critique the color story (the purple gradient), the face framing, contrast, and focal point. Does it feel like a wellness/movement app?
- Menu bar icon: a tiny colored face vs. the macOS norm of monochrome template icons. Argue both sides. Does the color help recognition or just add noise? Propose a monochrome/template alternative and say when each is better.
- Is there a recognizable **brand mark** here that could extend to a wordmark, app store screenshots, and a website?

### 2. Exercise / motion design language
- Does each animation **read unambiguously** as the stretch it claims to be, with no label? Which are confusing and why?
- Is the motion vocabulary consistent (timing, easing, amplitude, loop length) across the 12 moves, or do some feel faster/jankier?
- Are the groupings (Eyes / Neck / Shoulders / Full body) the right mental model? Is anything missing that a desk worker actually needs (wrists, lower back, hips, posture reset)?
- Is a single looping character the best teaching device, or would numbered steps, a hold-countdown, or a "do this many reps" cue communicate the exercise better?
- Accessibility: how does this work for color-blind users, reduced-motion users, and people who can't perceive subtle animation? What should change?

### 3. Overall design system
- Is there a consistent personality across icon, character, motion, and (future) typography/color? Name the personality in a sentence. Where does it break?
- What are the 3 highest-leverage changes to make Stretchy feel professionally designed rather than hobby-built?

## How to respond

1. **Snap verdict** — 2–3 sentences, your honest overall read.
2. **Scorecard** — rate each on 1–5 with one-line justification: Icon clarity, Icon distinctiveness, macOS fit, Menu bar icon, Motion readability, Motion consistency, Exercise coverage, Accessibility, Brand coherence.
3. **Findings** — for each weak area, state the problem, why it matters, and a specific fix (reference exact elements: colors, shapes, sizes, timings, exercise keys).
4. **Prioritized improvements** — a ranked list (high/medium/low effort × impact), concrete enough to implement.
5. **Three directions** — sketch 3 distinct alternative design languages for the icon + character (describe each in words: shape language, palette, mood, how the character is drawn), so I can choose a direction, not just tweaks.
6. **Open questions** — what you'd need to see (user data, more assets) to go deeper.

Be concrete, cite the specific element you're critiquing, and prefer "change X to Y because Z" over vague advice.
