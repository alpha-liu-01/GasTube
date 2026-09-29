; Per-user installer for a Windows release folder.
; SourceDir is the repo root. OutputDir and SetupIconFile are relative to that.
;   ISCC.exe /DAppVersion=0.9.3+16 /DVersionInfo=0.9.3.16 packaging\windows\gastube.iss
; ARM64: add /DSetupArch=arm64
#ifndef AppVersion
#define AppVersion "0.9.3+16"
#endif
#ifndef VersionInfo
#define VersionInfo "0.9.3.16"
#endif
#ifndef SetupArch
#define SetupArch "x64"
#endif

[Setup]
AppId={{8C4E2A71-6B19-4F0D-9C55-2E7A1D4B8F30}
AppName=GasTube
AppVersion={#AppVersion}
AppPublisher=GasTube
DefaultDirName={localappdata}\Programs\GasTube
PrivilegesRequired=lowest
ArchitecturesAllowed={#SetupArch}
ArchitecturesInstallIn64BitMode={#SetupArch}
SourceDir=..\..
OutputDir=dist
OutputBaseFilename=gastube-{#AppVersion}-windows-{#SetupArch}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\gastube.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#VersionInfo}
VersionInfoProductVersion={#VersionInfo}
DisableProgramGroupPage=yes

[Files]
Source: "build\windows\{#SetupArch}\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\GasTube"; Filename: "{app}\gastube.exe"
