; Second release shortcut for Lan Mouse.
;
; Lan Mouse takes a single release shortcut (release_bind in config.toml),
; which install.ps1 sets to Ctrl+Alt+Down. This keeps its default,
; Ctrl+Shift+Win+Alt, working too: with all four held it presses Down, which
; completes Ctrl+Alt+Down for Lan Mouse.
;
; While the mouse is on the other PC, Lan Mouse swallows every key in its
; keyboard hook, so this script has to start after the daemon to get its hook
; in first. lan-mouse-tray.exe starts it that way and stops it on Quit.
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

~LCtrl::
~LShift::
~LWin::
~LAlt::
{
    if GetKeyState("LCtrl", "P") && GetKeyState("LShift", "P")
        && GetKeyState("LWin", "P") && GetKeyState("LAlt", "P")
    {
        Send "{Blind}{Down}"
        ; once per press, not on every key repeat
        KeyWait SubStr(A_ThisHotkey, 2)
    }
}
