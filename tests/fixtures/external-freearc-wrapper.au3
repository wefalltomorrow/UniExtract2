#include <FileConstants.au3>
If $CmdLine[0] And $CmdLine[1] = "--child" Then
    Sleep(30000)
    Exit 0
EndIf
; Harmless synthetic wrapper. Never load a real unarc DLL or decode user input.
Local $sConfig = FileRead(@WorkingDir & "\config.ini")
Local $aOut = StringRegExp($sConfig, '(?m)^OutputPath=(.*)\r?$', 1)
Local $aMode = StringRegExp($sConfig, '(?m)^FixtureMode=(.*)\r?$', 1)
If UBound($aOut) <> 1 Or UBound($aMode) <> 1 Then Exit 90
Local $sOut = StringStripWS($aOut[0], 2), $sMode = StringStripWS($aMode[0], 2)
ConsoleWrite("SYNTHETIC-Secret-Only" & @CRLF)
ConsoleWriteError("SYNTHETIC-Secret-Only" & @CRLF)
Sleep(100)
If $sMode = "timeout" Or $sMode = "cancel" Then Sleep(30000)
If $sMode = "empty" Then Exit 0
If $sMode = "race" Then
    Local $aRace = StringRegExp($sConfig, '(?m)^FixtureDestination=(.*)\r?$', 1)
    DirCreate(StringStripWS($aRace[0], 2))
    FileWrite(StringStripWS($aRace[0], 2) & "\sentinel.txt", "keep")
EndIf
DirCreate($sOut & "\nested")
If $sMode = "child" Then
    Local $pid = Run('"' & @ScriptFullPath & '" --child', @WorkingDir, @SW_HIDE)
    FileWrite($sOut & "\child-pid.txt", $pid)
EndIf
If $sMode = "reparse" Then
    Local $aTarget = StringRegExp($sConfig, '(?m)^FixtureLinkTarget=(.*)\r?$', 1)
    If RunWait(@ComSpec & ' /d /c mklink /J "' & $sOut & '\link" "' & StringStripWS($aTarget[0], 2) & '"', @WorkingDir, @SW_HIDE) <> 0 Then Exit 94
EndIf
Local $h = FileOpen($sOut & "\nested\payload.txt", $FO_OVERWRITE + $FO_UTF8)
FileWrite($h, "fixture payload")
FileClose($h)
If $sMode = "nonzero" Then Exit 7
If Not StringInStr($sConfig, "Password=SYNTHETIC-Secret-Only", 1) Then Exit 91
If Not StringInStr($sConfig, "CfgFile=.\arc.ini", 1) Then Exit 92
If Not StringInStr($sConfig, "WorkPath=.\temp", 1) Then Exit 93
Exit 0
