' 隐藏窗口地启动 DSH desktop: 解析本脚本所在目录, 再调用同目录的 .bat。
' 这样整个 scripts/dsh.desktop.startup 目录可以整体复制到任意位置使用。
Option Explicit

Dim fso, scriptDir, batPath, shell
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
batPath = fso.BuildPath(scriptDir, "dsh.desktop.startup.gitbash.bat")

If Not fso.FileExists(batPath) Then
    MsgBox "Not found: " & batPath, 16, "DSH desktop startup"
    WScript.Quit 1
End If

Set shell = CreateObject("WScript.Shell")
' 0 = 隐藏窗口, False = 不等待(立即返回)。desktop 会自建窗口, 这里不必等待。
shell.Run "cmd /c """ & batPath & """", 0, False
