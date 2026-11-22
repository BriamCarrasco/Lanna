#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef OutputName
  #define OutputName "lanna-setup"
#endif

[Setup]
AppId={{8FE89C59-D8E2-483F-8B8B-3484872444FE}
AppName=Lanna
AppVersion={#AppVersion}
AppVerName=Lanna {#AppVersion}
AppPublisher=Lanna
AppPublisherURL=https://github.com/BriamCarrasco/Lanna
AppSupportURL=https://github.com/BriamCarrasco/Lanna/issues
AppUpdatesURL=https://github.com/BriamCarrasco/Lanna/releases
DefaultDirName={autopf}\Lanna
DefaultGroupName=Lanna
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\lanna.exe
UninstallDisplayName=Lanna
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Lanna"; Filename: "{app}\lanna.exe"
Name: "{autodesktop}\Lanna"; Filename: "{app}\lanna.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\lanna.exe"; Description: "{cm:LaunchProgram,Lanna}"; Flags: nowait postinstall skipifsilent
