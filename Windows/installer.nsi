Unicode True
!include "MUI2.nsh"
!include "FileFunc.nsh"
!ifndef VERSION
!error "VERSION is required"
!endif
!ifndef APP_DIR
!error "APP_DIR is required"
!endif
!ifndef OUTPUT
!error "OUTPUT is required"
!endif
Name "MiniVoice ${VERSION}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\MiniVoice"
InstallDirRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "MiniVoice"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"
Function .onVerifyInstDir
 ${GetRoot} "$INSTDIR" $0
 StrCmp "$INSTDIR" "$0\" invalid
 StrCmp "$INSTDIR" "$0" invalid
 StrCmp "$INSTDIR" "$WINDIR" invalid
 StrCmp "$INSTDIR" "$PROGRAMFILES" invalid
 StrCmp "$INSTDIR" "$PROGRAMFILES64" invalid
 Return
 invalid:
 Abort
FunctionEnd
Section "MiniVoice"
 SetShellVarContext current
 SetOutPath "$INSTDIR"
 SetOverwrite on
 ClearErrors
 File /r "${APP_DIR}\*.*"
 IfErrors 0 +3
 MessageBox MB_OK|MB_ICONSTOP "安装失败，请退出 MiniVoice 后重试。"
 Abort
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 CreateDirectory "$SMPROGRAMS\MiniVoice"
 CreateShortcut "$SMPROGRAMS\MiniVoice\MiniVoice.lnk" "$INSTDIR\MiniVoice.exe"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "DisplayName" "MiniVoice"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "DisplayVersion" "${VERSION}"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "InstallLocation" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "DisplayIcon" "$INSTDIR\MiniVoice.exe"
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "NoModify" 1
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice" "NoRepair" 1
SectionEnd
Section "Uninstall"
 SetShellVarContext current
 Delete "$SMPROGRAMS\MiniVoice\MiniVoice.lnk"
 RMDir "$SMPROGRAMS\MiniVoice"
 !include "${UNINSTALL_FILES}"
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice"
 ; User music and application preferences remain outside the installation.
SectionEnd
