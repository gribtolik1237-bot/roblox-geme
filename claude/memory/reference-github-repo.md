---
name: reference-github-repo
description: "TRAP LAB home repo on GitHub (owner-created 2026-11-17) - all project files live there; pull at start, commit+push at the end"
metadata:
  node_type: memory
  type: reference
  originSessionId: 7761e180-0db6-429b-ab6e-541062806e93
  modified: 2026-11-17T16:24:27.187Z
---

Owner created https://github.com/gribtolik1237-bot/roblox-geme (PUBLIC) on 2026-11-17 and asked that ALL TRAP LAB work be kept there "so you remember everything". Local clone: `C:\Users\yarik\AppData\Local\Roblox\roblox-geme` (gh is logged in as gribtolik1237-bot).

**How to apply:** start of a session: `git pull`, read `claude/README.md`, `claude/memory/`, `docs/HANDOFF.md`, newest `docs/NEXT_CHAT_PROMPT_S*.md`. End of work: update docs/ (and copy memory files into claude/memory/), export place scripts into `place/`, then commit + push (owner asked for it - standing permission for this repo). Commit identity: `gribtolik1237-bot` / `301790371+gribtolik1237-bot@users.noreply.github.com` - never the owner's personal email; repo is public, so no keys/tokens/cookies.
Place scripts export: `tools/recv.py` (local receiver on 127.0.0.1:8765) + execute_luau HttpService:PostAsync per script; BLOCKED until the owner adds 127.0.0.1 to the Studio Assistant HTTP allowlist (as of 2026-11-17 not added). See [[project-trap-lab]].
