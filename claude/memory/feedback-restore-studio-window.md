---
name: feedback-restore-studio-window
description: When Studio screenshots come back white, restore the Studio window yourself with the PowerShell script, do not ask the owner
metadata:
  type: feedback
---

Owner (2026-11-19): "ты должен сам его разворачивать, а не меня просить". After an emulator session the Studio viewport rendered white; I asked the owner to unminimize it.

**Why:** the owner wants autonomous work without stops for things a script can fix.

**How to apply:** run `tools/restore-studio-window.ps1` in the repo (ShowWindow + SetForegroundWindow on the RobloxStudioBeta process), then retake the capture. Ask only if that fails. See [[project-trap-lab]].
