# Restores and focuses the Roblox Studio window when the 3D viewport stops rendering (white screen_capture frames).
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools/restore-studio-window.ps1
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h); }
"@
$p = Get-Process | Where-Object { $_.ProcessName -like "RobloxStudio*" -and $_.MainWindowTitle -ne "" } | Select-Object -First 1
if ($p) { [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null; [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; "restored: " + $p.MainWindowTitle } else { "no Studio window found" }
