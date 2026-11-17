---
name: feedback-build-snapping
description: "TRAP LAB building bug the owner flagged - pieces cannot be joined end to end, gaps stay between them; fix first next session"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c96a6286-084b-44b0-a40b-ebc67aac6e17
  modified: 2026-11-16T20:16:17.631Z
---

Owner (2026-11-16, end of session 6, with screenshots): obstacles CANNOT be joined to each other - a gap always stays between pieces, and pushing them together gives "Something is in the way". Building is unusable without this. «запомни это».

**Why:** the course only works when pieces link (entry/exit gap <= Balance.MaxGap), and the owner tries to build it by hand and fails.

**How to apply:** FIXED in session 7 (v158): magnet snapping + coloured ghost + symmetric 180=0 (TASKS T56/T57). Keep it working: re-test joining after any BuildController change. Try it yourself in Play (real mouse, two different pieces end to end, also rotated 90°). Likely cause (unverified): `PlotMath.snapCentre` snaps the box MIN corner to the 4-stud grid, but many sizes are not multiples of 4 (Conveyor 18, Lava 24 ok, Spike 20 ok, Finish 14, SmallJump 6, Rotating 24/14, Moving 34...) so the far edge lands off-grid -> next piece can't touch it, only overlap (rejected) or leave a 2-stud gap. Fix idea: snap to the EXIT edge of the nearest placed piece (magnet: if the ghost's entry is within ~4 studs of an existing exit, place it flush and aligned), keep the grid only as fallback; show a "joins here" highlight. Also check the ghost has its green/red Highlight (dark ghost on the owner's screenshot). Verify with screenshots, then NPC run on the joined course. See [[project-trap-lab]], [[feedback-tutorial-arrows]].
