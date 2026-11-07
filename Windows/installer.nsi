Unicode True
!define MUI_ICON "assets/MiniVoice.ico"
!define MUI_UNICON "assets/MiniVoice.ico"
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "WordFunc.nsh"
!include "nsDialogs.nsh"
!include "x64.nsh"
!ifndef VERSION
!error "VERSION is required"
!endif
!ifndef APP_DIR
!error "APP_DIR is required"
!endif
!ifndef OUTPUT
!error "OUTPUT is required"
!endif
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MiniVoice"
Name "MiniVoice ${VERSION}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\MiniVoice"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor zlib
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "MiniVoice"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "MiniVoice Windows x64 Installer"
VIAddVersionKey "LegalCopyright" "MiniVoice"
Var Dialog
Var DesktopControl
Var StartControl
Var DesktopChoice
Var StartChoice
Var PreviousDir
Var PreviousVersion
Var Upgrading
Var BackupDir
Var Status
Var InstallerMutex
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPage OptionsLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\MiniVoice.exe"
!define MUI_FINISHPAGE_RUN_TEXT "$(LaunchText)"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"
LangString ModelCheckText ${LANG_SIMPCHINESE} "正在检查已有离线模型…"
LangString ModelCheckText ${LANG_ENGLISH} "Checking the installed offline model..."
LangString ModelReuseText ${LANG_SIMPCHINESE} "离线模型未变，已跳过解压和覆盖。"
LangString ModelReuseText ${LANG_ENGLISH} "Offline model unchanged; skipping extraction and replacement."
LangString ModelInstallText ${LANG_SIMPCHINESE} "正在安装离线模型（首次安装或修复）…"
LangString ModelInstallText ${LANG_ENGLISH} "Installing the offline model (first install or repair)..."
LangString ApplyFilesText ${LANG_SIMPCHINESE} "正在校验并更新应用文件；未变文件将保留。"
LangString ApplyFilesText ${LANG_ENGLISH} "Verifying and updating application files; retaining unchanged files."
LangString LaunchText ${LANG_SIMPCHINESE} "安装完成后启动 MiniVoice"
LangString LaunchText ${LANG_ENGLISH} "Launch MiniVoice after installation"
LangString OptionsTitle ${LANG_SIMPCHINESE} "快捷方式与更新"
LangString OptionsTitle ${LANG_ENGLISH} "Shortcuts and updates"
LangString OptionsSubtitle ${LANG_SIMPCHINESE} "选择图标显示位置；更新保留音乐库和个人设置。"
LangString OptionsSubtitle ${LANG_ENGLISH} "Choose shortcut locations. Updates preserve your library and settings."
LangString DesktopText ${LANG_SIMPCHINESE} "在桌面创建快捷方式"
LangString DesktopText ${LANG_ENGLISH} "Create a desktop shortcut"
LangString StartText ${LANG_SIMPCHINESE} "在开始菜单创建快捷方式"
LangString StartText ${LANG_ENGLISH} "Create a Start menu shortcut"
LangString UpdateText ${LANG_SIMPCHINESE} "已安装版本：$PreviousVersion。将在原位置更新或修复。$\r$\n音乐文件、收藏、歌单和设置保留。快捷方式沿用上次选择，可在此修改。"
LangString UpdateText ${LANG_ENGLISH} "Installed version: $PreviousVersion. Update or repair in the same location.$\r$\nMusic, favorites, playlists and settings are preserved. Previous shortcut choices can be changed here."
LangString FreshText ${LANG_SIMPCHINESE} "仅为当前用户安装。后续运行新版安装包即可覆盖升级，无需先卸载。$\r$\n更新前请从托盘退出应用；安装器不会强制结束播放或编辑。"
LangString FreshText ${LANG_ENGLISH} "Install for the current user. Run a newer installer to update; no uninstall is needed.$\r$\nQuit MiniVoice from the tray before updating. The installer does not force-close playback or editing."
LangString BusyText ${LANG_SIMPCHINESE} "请先从托盘退出 MiniVoice，并等待歌词匹配结束，然后重试。"
LangString BusyText ${LANG_ENGLISH} "Quit MiniVoice from the tray and wait for lyric alignment to finish, then retry."
LangString FailedText ${LANG_SIMPCHINESE} "安装未完成。请退出 MiniVoice 后重试，或检查安装目录权限和可用空间。"
LangString FailedText ${LANG_ENGLISH} "Installation failed. Quit MiniVoice and check directory permissions and free space before retrying."

!macro InstallerLock
 System::Call 'kernel32::CreateMutexW(p 0, i 0, w "Local\MiniVoiceInstaller") p .r0 ?e'
 Pop $1
 StrCpy $InstallerMutex $0
 ${If} $1 = 183
  MessageBox MB_OK|MB_ICONEXCLAMATION "MiniVoice 安装或卸载程序正在运行。 / MiniVoice setup is already running."
  Abort
 ${EndIf}
!macroend
Function .onInit
 ${IfNot} ${RunningX64}
  MessageBox MB_OK|MB_ICONSTOP "此安装包需要 64 位 Windows。 / 64-bit Windows is required."
  Abort
 ${EndIf}
 !insertmacro InstallerLock
 SetShellVarContext current
 SetRegView 64
 StrCpy $DesktopChoice ${BST_CHECKED}
 StrCpy $StartChoice ${BST_CHECKED}
 StrCpy $Upgrading 0
 ReadRegStr $PreviousDir HKCU "${UNINSTALL_KEY}" "InstallLocation"
 ReadRegStr $PreviousVersion HKCU "${UNINSTALL_KEY}" "DisplayVersion"
 ${If} $PreviousDir != ""
 ${AndIf} ${FileExists} "$PreviousDir\MiniVoice.exe"
  StrCpy $Upgrading 1
  StrCpy $INSTDIR $PreviousDir
  ${VersionCompare} "$PreviousVersion" "${VERSION}" $0
  ${If} $0 = 1
   MessageBox MB_OK|MB_ICONSTOP "已安装更新版本 $PreviousVersion，不能安装较旧的 ${VERSION}。 / A newer version is already installed."
   Abort
  ${EndIf}
  ClearErrors
  ReadRegDWORD $0 HKCU "${UNINSTALL_KEY}" "DesktopShortcut"
  ${IfNot} ${Errors}
   StrCpy $DesktopChoice $0
  ${Else}
   StrCpy $DesktopChoice ${BST_UNCHECKED}
   ${If} ${FileExists} "$DESKTOP\MiniVoice.lnk"
    StrCpy $DesktopChoice ${BST_CHECKED}
   ${EndIf}
  ${EndIf}
  ClearErrors
  ReadRegDWORD $0 HKCU "${UNINSTALL_KEY}" "StartMenuShortcut"
  ${IfNot} ${Errors}
   StrCpy $StartChoice $0
  ${EndIf}
 ${EndIf}
FunctionEnd
Function DirectoryPre
 ${If} $Upgrading = 1
  Abort
 ${EndIf}
FunctionEnd
Function OptionsPage
 !insertmacro MUI_HEADER_TEXT "$(OptionsTitle)" "$(OptionsSubtitle)"
 nsDialogs::Create 1018
 Pop $Dialog
 ${If} $Dialog == error
  Abort
 ${EndIf}
 ${NSD_CreateCheckbox} 0 6u 100% 14u "$(DesktopText)"
 Pop $DesktopControl
 ${NSD_SetState} $DesktopControl $DesktopChoice
 ${NSD_CreateCheckbox} 0 30u 100% 14u "$(StartText)"
 Pop $StartControl
 ${NSD_SetState} $StartControl $StartChoice
 ${If} $Upgrading = 1
  ${NSD_CreateLabel} 0 60u 100% 62u "$(UpdateText)"
 ${Else}
  ${NSD_CreateLabel} 0 60u 100% 62u "$(FreshText)"
 ${EndIf}
 Pop $0
 nsDialogs::Show
FunctionEnd
Function OptionsLeave
 ${NSD_GetState} $DesktopControl $DesktopChoice
 ${NSD_GetState} $StartControl $StartChoice
FunctionEnd
Function .onVerifyInstDir
 ${GetRoot} "$INSTDIR" $0
 StrCmp "$INSTDIR" "$0\" invalid
 StrCmp "$INSTDIR" "$0" invalid
 StrCmp "$INSTDIR" "$WINDIR" invalid
 StrCmp "$INSTDIR" "$PROGRAMFILES" invalid
 StrCmp "$INSTDIR" "$PROGRAMFILES64" invalid
 ${If} $Upgrading = 1
  StrCmp "$INSTDIR" "$PreviousDir" 0 invalid
 ${EndIf}
 Return
 invalid:
 Abort
FunctionEnd
Section "MiniVoice"
 SetShellVarContext current
 SetRegView 64
 InitPluginsDir
 SetOutPath "$PLUGINSDIR\payload"
 File /r /x small.pt "${APP_DIR}\*.*"
 SetOutPath "$PLUGINSDIR"
 File "install-update.py"
 update_retry:
 DetailPrint "$(ModelCheckText)"
 nsExec::ExecToStack '"$PLUGINSDIR\payload\resources\app.asar.unpacked\resources\LyricsAI\python.exe" "$PLUGINSDIR\install-update.py" --source "$PLUGINSDIR\payload" --target "$INSTDIR" --can-reuse-model'
 Pop $0
 Pop $1
 ${If} $0 = 0
  DetailPrint "$(ModelReuseText)"
 ${Else}
  DetailPrint "$(ModelInstallText)"
  SetOutPath "$PLUGINSDIR\payload\resources\app.asar.unpacked\resources\LyricsAI\models"
  File /oname=small.pt "${APP_DIR}\resources\app.asar.unpacked\resources\LyricsAI\models\small.pt"
  SetOutPath "$PLUGINSDIR"
 ${EndIf}
 Delete "$PLUGINSDIR\install-status.txt"
 CreateDirectory "$LOCALAPPDATA\MiniVoice\InstallerBackups"
 GetTempFileName $BackupDir "$LOCALAPPDATA\MiniVoice\InstallerBackups"
 Delete "$BackupDir"
 CreateDirectory "$BackupDir"
 DetailPrint "$(ApplyFilesText)"
 nsExec::ExecToStack '"$PLUGINSDIR\payload\resources\app.asar.unpacked\resources\LyricsAI\python.exe" "$PLUGINSDIR\install-update.py" --source "$PLUGINSDIR\payload" --target "$INSTDIR" --backup "$BackupDir" --status "$PLUGINSDIR\install-status.txt"'
 Pop $0
 Pop $1
 ${If} $0 != 0
  StrCpy $Status "$(FailedText)"
  ClearErrors
  FileOpen $0 "$PLUGINSDIR\install-status.txt" r
  ${IfNot} ${Errors}
   FileSeek $0 2 SET
   FileReadUTF16LE $0 $Status
   FileClose $0
  ${EndIf}
  MessageBox MB_RETRYCANCEL|MB_ICONSTOP "$Status" /SD IDCANCEL IDRETRY update_retry
  SetErrorLevel 1
  Quit
 ${EndIf}
 SetOutPath "$INSTDIR"
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 ${If} $DesktopChoice = ${BST_CHECKED}
  CreateShortcut "$DESKTOP\MiniVoice.lnk" "$INSTDIR\MiniVoice.exe" "" "$INSTDIR\MiniVoice.exe" 0
 ${Else}
  Delete "$DESKTOP\MiniVoice.lnk"
 ${EndIf}
 ${If} $StartChoice = ${BST_CHECKED}
  CreateDirectory "$SMPROGRAMS\MiniVoice"
  CreateShortcut "$SMPROGRAMS\MiniVoice\MiniVoice.lnk" "$INSTDIR\MiniVoice.exe" "" "$INSTDIR\MiniVoice.exe" 0
 ${Else}
  Delete "$SMPROGRAMS\MiniVoice\MiniVoice.lnk"
  RMDir "$SMPROGRAMS\MiniVoice"
 ${EndIf}
 WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "MiniVoice"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
 WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
 WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" '$\"$INSTDIR\MiniVoice.exe$\",0'
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "DesktopShortcut" $DesktopChoice
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "StartMenuShortcut" $StartChoice
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
 WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd
Function un.onInit
 !insertmacro InstallerLock
 SetShellVarContext current
 SetRegView 64
 un_retry:
 IfFileExists "$INSTDIR\MiniVoice.exe" 0 un_ready
 ClearErrors
 FileOpen $0 "$INSTDIR\MiniVoice.exe" a
 IfErrors un_busy
 FileClose $0
 Goto un_ready
 un_busy:
 MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(BusyText)" /SD IDCANCEL IDRETRY un_retry
 Abort
 un_ready:
FunctionEnd
Section "Uninstall"
 SetShellVarContext current
 SetRegView 64
 Delete "$DESKTOP\MiniVoice.lnk"
 Delete "$SMPROGRAMS\MiniVoice\MiniVoice.lnk"
 RMDir "$SMPROGRAMS\MiniVoice"
 !include "${UNINSTALL_FILES}"
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 DeleteRegKey HKCU "${UNINSTALL_KEY}"
 ; User music and application preferences remain outside the installation.
SectionEnd
