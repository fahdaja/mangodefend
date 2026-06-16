' MangoDefend Launcher
' Runs the application as Administrator with no visible terminal window.
' Double-click this file to launch MangoDefend.

Dim oShell, oFSO, sDir, sBat

Set oShell = CreateObject("Shell.Application")
Set oFSO   = CreateObject("Scripting.FileSystemObject")

' Resolve the directory where this .vbs file lives
sDir = oFSO.GetParentFolderName(WScript.ScriptFullName)
sBat = sDir & "\run.bat"

' ShellExecute with "runas" = UAC prompt, WindowStyle 0 = hidden window
oShell.ShellExecute "cmd.exe", "/c """ & sBat & """", sDir, "runas", 0

Set oShell = Nothing
Set oFSO   = Nothing
