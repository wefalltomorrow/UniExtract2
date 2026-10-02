#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=support\Icons\uniextract_exe.ico
#AutoIt3Wrapper_Outfile=UniExtractUpdater_NoAdmin.exe
#AutoIt3Wrapper_Res_Description=Update utility for Universal Extractor
#AutoIt3Wrapper_Res_Fileversion=3.1.0.0
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/mo
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.2
 Author:         Bioruebe

 Script Function:
	Auto-updater for Universal Extractor

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

#include <Array.au3>
#include <GUIConstants.au3>
#include <Inet.au3>

Const $sUpdaterTitle = "Universal Extractor Updater"
Const $sMainUpdateURL = "https://github.com/wefalltomorrow/UniExtract2/releases/latest/download/UniExtract.exe"
Const $sMainNighlyUpdateURL = "https://github.com/wefalltomorrow/UniExtract2/releases/download/nightly/UniExtract.exe"
; FFmpeg is still sourced from the maintained helper bundle until this fork publishes equivalent assets.
Const $sFFmpegUpdateURL_x86 = "https://github.com/gvp9000/UniExtract2/releases/latest/download/ffmpeg_x86.exe"
Const $sFFmpegUpdateURL_x64 = "https://github.com/gvp9000/UniExtract2/releases/latest/download/ffmpeg_x64.exe"
Const $sFFmpegLicenseURL = "https://ffmpeg.org/legal.html"
Const $sUniExtract = @ScriptDir & "\UniExtract.exe"

If Not FileExists($sUniExtract) Then
	If MsgBox(16+4, $sUpdaterTitle, "Universal Extractor main executable not found in current directory." & @CRLF & @CRLF & "Path is " & $sUniExtract & @CRLF & @CRLF & "Do you want to redownload Universal Extractor?") == 6 Then _
		_UpdateUniExtract()
	Exit
EndIf

If $cmdline[0] < 1 Then Exit ShellExecute($sUniExtract, "/update")

Sleep(50)

If $cmdline[1] == "/pluginst" Then
	; To install plugins we just start UniExtract elevated
	Exit ShellExecute($sUniExtract, "/plugins")
ElseIf $cmdline[1] == "/main" Then
	_UpdateUniExtract(_ArraySearch($cmdline, "/nightly") > -1)
ElseIf $cmdline[1] == "/helper" Then
	Exit ShellExecute($sUniExtract, "/updatehelper")
ElseIf $cmdline[1] == "/ffmpeg" Then
	_GetFFMPEG()
EndIf

Func _UpdateUniExtract($bNightly = False)
	If Not ProcessWaitClose($sUniExtract, 10) Then Exit MsgBox(16, $sUpdaterTitle, "Failed to close Universal Extractor. Please terminate the process manually and try again.")

	_Download($bNightly ? $sMainNighlyUpdateURL : $sMainUpdateURL)
	$error = @error

	Sleep(100)
	Exit ShellExecute($sUniExtract, $error ? "" : "/afterupdate")
EndFunc

Func _GetFFMPEG()
	Local $sOSArchDir = @ScriptDir & "\bin\" & (@OSArch = "X64" ? "x64" : "x86")
	Local $sFFmpegURL = (@OSArch = "X64" ? $sFFmpegUpdateURL_x64 : $sFFmpegUpdateURL_x86)
	Local $sLicenseFile = @ScriptDir & "\docs\FFmpeg_license.html"

	DirCreate($sOSArchDir)
	DirCreate(@ScriptDir & "\docs")

	Local $sFFmpegFile = $sOSArchDir & "\ffmpeg.exe"

	_Download($sFFmpegURL, $sFFmpegFile, True, True)
	If @error Then Exit 1

	If Not FileExists($sFFmpegFile) Then _
		Exit MsgBox(48, $sUpdaterTitle, "Failed to download ffmpeg.exe to " & $sOSArchDir & "\")

	If Not FileExists($sLicenseFile) Then _
		_Download($sFFmpegLicenseURL, $sLicenseFile, False, True)

	ShellExecute($sUniExtract)
EndFunc

Func _Download($sURL, $sDir = @ScriptDir, $bCreateBackup = True, $bIsFilePath = False)
	; Create GUI with progressbar
	Local $hGUI = GUICreate("Downloading", 466, 109, -1, -1, $WS_POPUPWINDOW, -1)
	GUICtrlCreateLabel($sURL, 8, 16, 446, 17, $SS_CENTER)
	Local $idProgress = GUICtrlCreateProgress(8, 46, 446, 25)
	GUISetState(@SW_SHOW)

	; Get file size
	Local $iBytesReceived = 0
	Local $iBytesTotal = InetGetSize($sURL)
	If $iBytesTotal < 1 Then $iBytesTotal = 1
	Local $idSize = GUICtrlCreateLabel($iBytesReceived & "/" & $iBytesTotal & " bytes", 8, 76, 446, 17, $SS_CENTER)

	; Download File
	Local $sFile = $bIsFilePath ? $sDir : $sDir & "\" & StringTrimLeft($sURL, StringInStr($sURL, "/", 0, -1))
	Local $sBackupFile = $sFile & ".bak"

	If $bCreateBackup And FileExists($sFile) Then FileMove($sFile, $sBackupFile)

	Local $hDownload = InetGet($sURL, $sFile, 1, 1)

	; Update progress bar
	While Not InetGetInfo($hDownload, 2)
		Sleep(50)
		If InetGetInfo($hDownload, 4) <> 0 Then
			GUIDelete($hGUI)
			If $bCreateBackup Then FileMove($sBackupFile, $sFile, 1)
			_DownloadError($sURL)
			Return SetError(1, 0, 0)
		EndIf
		$iBytesReceived = InetGetInfo($hDownload, 0)
		GUICtrlSetData($idProgress, Int($iBytesReceived / $iBytesTotal * 100))
		GUICtrlSetData($idSize, $iBytesReceived & "/" & $iBytesTotal & " bytes")
	WEnd

	; Close GUI
	GUIDelete($hGUI)
	If Not FileExists($sFile) Then
		If $bCreateBackup Then FileMove($sBackupFile, $sFile, 1)
		_DownloadError($sURL)
		Return SetError(1, 0, 0)
	EndIf

	If $bCreateBackup Then FileDelete($sBackupFile)
	Return $sFile
EndFunc

Func _DownloadError($sURL)
	MsgBox(48, $sUpdaterTitle, 'The file ' & $sURL & ' could not be downloaded. Please ensure that you are connected to the internet and try again.')
EndFunc
