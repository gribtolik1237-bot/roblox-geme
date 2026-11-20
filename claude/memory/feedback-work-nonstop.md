---
name: feedback-work-nonstop
description: "TRAP LAB - work without stopping until EVERYTHING in the session prompt is done; do not pause to ask \"start?\""
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3808cf7b-455e-432b-bfe3-a56cba9056e3
  modified: 2026-11-20T07:35:06.810Z
---

When the owner gives a session prompt (docs/NEXT_CHAT_PROMPT_S*.md), work through ALL of its items without stopping: do not end the turn to ask "начинать?" or wait for "продолжать". Stop only at the usage limit (95-97 % of the 5-hour window, exact number from get_usage) or when a real owner decision is needed.

**Why:** owner said 2026-11-20 "работай без остановок пока не выполнишь вопще всё что написано в промте ... запомни это" after I stopped at the start of S11 waiting for "продолжать".

Owner added the same day: "и на промты тоже опирайся" - base every decision on the prompts too: docs/MASTER_PROMPT.md (10 standards, chief cycle, override table), the current session prompt and the older NEXT_CHAT_PROMPT_S*.md rules.

**How to apply:** pasting the prompt = start everything, including TECH-05. Ask only real decisions (prices, deleting owner content, downloads), and keep working on other items meanwhile. Related: [[project-trap-lab]], [[reference-roblox-craft-studio-skill]], [[feedback-language-russian]].
