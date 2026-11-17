---
name: feedback-art-quality
description: "User's hard rule for TRAP LAB visuals - no \"AI slop\"; actually read the art skills and review real screenshots before calling any design done"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6a4bab5d-d033-4517-b76b-87ca790a52de
  modified: 2026-11-16T06:25:00.331Z
---

On 2026-11-15 the user said the current TRAP LAB design (buttons, shops, signs, models) looks like "жёсткий нейрослоп" and that it felt like I never looked at the skills. They told me to REMEMBER this.

**Why:** I loaded `game-art-direction` but never read its references (references/interfaces.md, other-visuals.md, review.md, blender.md) and built visuals blind (3D capture was blank), using default-looking flat boxes, generic navy panels and neon strips.

**How to apply:** For ANY visual work (UI, signs, shops, models, lighting): (1) invoke `anthropic-skills:game-art-direction` AND read the relevant reference files in its `references/` folder (path: C:\Users\yarik\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\local-agent-mode-sessions\skills-plugin\c1bd64ad-bc0e-4a72-a5fc-3840de49a316\4a34f6d2-cba7-4e19-9139-4bee56b57125\skills\game-art-direction\references\); do NOT use `crystal-rush-art-style` or the old Crystal Rush game as a reference (user said so on 2026-11-15); the design skills to use are `game-art-direction` (main), `impeccable`, `frontend-design`, `roblox-gui`, `roblox-lighting`. (2) State a short art direction (shape language, palette roles, materials, one accent). (3) Look at real screenshots (Studio window must be visible: MCP screen_capture works only then; computer-use access to Roblox Studio is granted by the user) and critique against the review checklist before AND after changes. (4) Do not call visuals "done" without screenshots.
User also said (2026-11-15): "я тебе всё разрешаю, делай всё сам, напиши когда доделаешь все задания по промту или когда что-то понадобится" - work autonomously, report only when all spec tasks are done or something is needed.

User-provided GOOD-design reference screenshots (not slop): C:\Users\yarik\AppData\Local\Roblox\TRAP_LAB\примеры современного дизайна который не неерослоп (6 PNG). Open and study them BEFORE any visual work; compare own screenshots against them (principles, not 1:1 copying).

Lesson 2026-11-16 (session 4): user said my first donate icons "выглядят не доработано" and "всё что делаешь нужно тщательно проверять, а потом только добавлять в игру". I had judged them OK after one pass and wired them in. Rule: iterate each asset until it holds up against the references (thick ink outline, ONE big hero object, no filler base plate, readable at the real in-game size ~100px - make a contact sheet), view EVERY render, name concrete defects, and only then upload + wire into the game; then re-check in a real Play screenshot (it caught an unloaded icon and a pasted-tile look).
Lesson 2026-11-16: my first TRAP LAB direction (graphite + hazard yellow + neon rims) CONTRADICTED the user's references, which are bright, saturated, studded "brick-toy" scenes with fat outlined text, striped awnings, wooden frames and glow rings only for interaction zones. Derive the direction FROM the reference screenshots (write the observed facts first), then check every screenshot against them; the redone pass (Hall, plots, shops, obstacles, HUD) is documented in docs/ART_DIRECTION.md.
