#ifndef MyRuntime
  #define MyRuntime "win-x64"
#endif
#ifndef PublishDir
  #define PublishDir "..\artifacts\publish\" + MyRuntime
#endif
[Setup]
AppId={{40C412F1-04E2-47F7-82A4-EF7A80ED73BD}
AppName=MinuteCapture
AppVersion=1.0.0
AppPublisher=MinuteCapture
DefaultDirName={localappdata}\Programs\MinuteCapture
DefaultGroupName=MinuteCapture
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\MinuteCapture.exe
SetupIconFile=..\MinuteCapture\Assets\MinuteCapture.ico
OutputDir=..\artifacts\installer\{#MyRuntime}
OutputBaseFilename=MinuteCapture-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
#if MyRuntime == "win-arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\MinuteCapture"; Filename: "{app}\MinuteCapture.exe"
Name: "{group}\Uninstall MinuteCapture"; Filename: "{uninstallexe}"
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "MinuteCapture"; Flags: uninsdeletevalue
[Run]
Filename: "{app}\MinuteCapture.exe"; Description: "Open MinuteCapture"; Flags: nowait postinstall skipifsilent