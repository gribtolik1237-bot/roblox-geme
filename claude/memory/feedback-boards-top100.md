---
name: feedback-boards-top100
description: "TRAP LAB leaderboards must show TOP 100 and scroll up/down (owner 2026-11-20, decision D-039)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3808cf7b-455e-432b-bfe3-a56cba9056e3
  modified: 2026-11-20T08:46:42.358Z
---

Leaderboard stands in the Hall must list the top 100 and be scrollable up and down (not top-10, not top-5).

**Why:** owner answered 2026-11-20 "доски лидеров должны быть топ 100 чтобы доску можно было листать в верх и вниз" when asked about shrinking to top-5 for phone readability.

**How to apply:** follow docs/DECISIONS.md D-039: Balance.Boards.Size 100 (GetSortedAsync page max 100), server publishes rows, client builds the face as a SurfaceGui in PlayerGui with Adornee = board part (SurfaceGuis in Workspace get no input) holding a fixed BoardSkin header + ScrollingFrame of 100 rows, "You: #N" row if possible. Test scroll with user_mouse_input scrollUp/Down; touch drag stays NOT TESTED in the emulator. Related: [[project-trap-lab]].
