Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
venvPythonW = scriptDir & "\.venv\Scripts\pythonw.exe"
If CreateObject("Scripting.FileSystemObject").FileExists(venvPythonW) Then
    WshShell.Run """" & venvPythonW & """ """ & scriptDir & "\winter_desktop.py""", 0, False
Else
    WshShell.Run "pythonw """ & scriptDir & "\winter_desktop.py""", 0, False
End If
