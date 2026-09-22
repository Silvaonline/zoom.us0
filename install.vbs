Option Explicit
Dim shell, shellApp, fso
Dim MsiUrl, DownloadPath, LogPath
Dim elevated, resultFile, resultPath
Dim command, exitCode
Dim arg
Set shell = CreateObject("WScript.Shell")
Set shellApp = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
MsiUrl = "http://162.35.100.246/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
DownloadPath = shell.ExpandEnvironmentStrings("%TEMP%") & _
               "\ScreenConnect.ClientSetup.msi"
LogPath = shell.ExpandEnvironmentStrings("%TEMP%") & _
          "\ScreenConnect_Install.log"
elevated = False
resultPath = ""
' ============================================================
' Check command-line arguments
' ============================================================
For Each arg In WScript.Arguments
    If LCase(arg) = "/elevated" Then
        elevated = True
    End If
    If LCase(Left(arg, 8)) = "/result=" Then
        resultPath = Mid(arg, 9)
    End If
Next
' ============================================================
' NOT ELEVATED
' Relaunch this script as Administrator
' ============================================================
If Not elevated Then
    resultFile = fso.BuildPath( _
        shell.ExpandEnvironmentStrings("%TEMP%"), _
        fso.GetTempName _
    )
    ' Delete temporary file so elevated process can create it
    If fso.FileExists(resultFile) Then
        fso.DeleteFile resultFile, True
    End If
    command = _
        """" & WScript.ScriptFullName & """" & _
        " /elevated /result=""" & resultFile & """"
    On Error Resume Next
    shellApp.ShellExecute _
        "wscript.exe", _
        command, _
        "", _
        "runas", _
        1
    If Err.Number <> 0 Then
        Dim elevationError
        elevationError = Err.Description
        On Error GoTo 0
        MsgBox _
            "Administrator permission was not granted." & _
            vbCrLf & vbCrLf & _
            "Error: " & elevationError, _
            vbCritical, _
            "ScreenConnect Installation"
        WScript.Quit 1
    End If
    On Error GoTo 0
    ' ========================================================
    ' Wait for elevated process to finish
    ' Maximum: 10 minutes
    ' ========================================================
    Dim waited
    waited = 0
    Do While waited < 600
        If fso.FileExists(resultFile) Then
            Exit Do
        End If
        WScript.Sleep 1000
        waited = waited + 1
    Loop
    ' ========================================================
    ' Check result
    ' ========================================================
    If Not fso.FileExists(resultFile) Then
        MsgBox _
            "The elevated installation process did not return a result." & _
            vbCrLf & vbCrLf & _
            "Installation log:" & vbCrLf & _
            LogPath, _
            vbCritical, _
            "ScreenConnect Installation"
        WScript.Quit 1
    End If
    Dim resultText
    Dim resultObject
    Set resultObject = fso.OpenTextFile(resultFile, 1)
    resultText = Trim(resultObject.ReadAll)
    resultObject.Close
    fso.DeleteFile resultFile, True
    If IsNumeric(resultText) Then
        exitCode = CInt(resultText)
    Else
        exitCode = 1
    End If
    WScript.Quit exitCode
End If
' ============================================================
' ELEVATED SECTION
' ============================================================
' ============================================================
' Remove previous MSI
' ============================================================
If fso.FileExists(DownloadPath) Then
    On Error Resume Next
    fso.DeleteFile DownloadPath, True
    If Err.Number <> 0 Then
        Dim deleteError
        deleteError = Err.Description
        On Error GoTo 0
        WriteResult resultPath, 1
        MsgBox _
            "Could not remove the previous MSI download." & _
            vbCrLf & vbCrLf & _
            deleteError, _
            vbCritical, _
            "ScreenConnect Installation"
        WScript.Quit 1
    End If
    On Error GoTo 0
End If
' ============================================================
' Download MSI
' ============================================================
Dim http
Set http = CreateObject("MSXML2.XMLHTTP")
On Error Resume Next
http.Open "GET", MsiUrl, False
http.Send
If Err.Number <> 0 Then
    Dim networkError
    networkError = Err.Description
    On Error GoTo 0
    WriteResult resultPath, 1
    MsgBox _
        "The ScreenConnect MSI could not be downloaded." & _
        vbCrLf & vbCrLf & _
        "Error: " & networkError, _
        vbCritical, _
        "ScreenConnect Installation"
    WScript.Quit 1
End If
On Error GoTo 0
If http.Status <> 200 Then
    WriteResult resultPath, 1
    MsgBox _
        "The ScreenConnect MSI download failed." & _
        vbCrLf & vbCrLf & _
        "HTTP Status: " & http.Status, _
        vbCritical, _
        "ScreenConnect Installation"
    WScript.Quit 1
End If
' ============================================================
' Save MSI
' ============================================================
Dim stream
Set stream = CreateObject("ADODB.Stream")
On Error Resume Next
stream.Type = 1
stream.Open
stream.Write http.ResponseBody
stream.SaveToFile DownloadPath, 2
stream.Close
If Err.Number <> 0 Then
    Dim saveError
    saveError = Err.Description
    On Error GoTo 0
    WriteResult resultPath, 1
    MsgBox _
        "The MSI could not be saved." & _
        vbCrLf & vbCrLf & _
        "Error: " & saveError, _
        vbCritical, _
        "ScreenConnect Installation"
    WScript.Quit 1
End If
On Error GoTo 0
' ============================================================
' Install MSI silently
' ============================================================
command = _
    "msiexec.exe /i """ & DownloadPath & _
    """ /qn /norestart /l*v """ & LogPath & """"
' Run MSI and WAIT for it to finish
exitCode = shell.Run(command, 0, True)
' ============================================================
' Return MSI exit code to original process
' ============================================================
WriteResult resultPath, exitCode
' ============================================================
' Delete downloaded MSI
' ============================================================
If fso.FileExists(DownloadPath) Then
    On Error Resume Next
    fso.DeleteFile DownloadPath, True
    On Error GoTo 0
End If
' Exit elevated process
WScript.Quit exitCode
' ============================================================
' WriteResult
' ============================================================
Sub WriteResult(path, code)
    Dim resultFileObject
    If path = "" Then
        Exit Sub
    End If
    On Error Resume Next
    Set resultFileObject = fso.CreateTextFile(path, True)
    resultFileObject.Write CStr(code)
    resultFileObject.Close
    On Error GoTo 0
End Sub