#ifndef BuildRoot
 #error BuildRoot is required
#endif
#ifndef OutputRoot
 #error OutputRoot is required
#endif
[Setup]
AppId={{3E824C17-87A2-41C7-A45D-5C253B1DABF5}
AppName=Rise On Air · 理世主题
AppVersion=1.0.7
AppPublisher=qt0713
AppPublisherURL=https://github.com/qt0713/RiseOnAir-Codex-P4R
AppSupportURL=https://github.com/qt0713/RiseOnAir-Codex-P4R/issues
DefaultDirName={localappdata}\Programs\RiseOnAir
DefaultGroupName=Rise On Air
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
Compression=lzma2/normal
SolidCompression=yes
OutputDir={#OutputRoot}
OutputBaseFilename=RiseOnAir-Setup-v1.0.7-windows-x64
SetupIconFile={#BuildRoot}\rise-icon-v1.ico
UninstallDisplayIcon={app}\rise-icon-v1.ico
VersionInfoVersion=1.0.7.0
VersionInfoDescription=Rise On Air · 理世主题安装包
VersionInfoProductName=Rise On Air
ChangesAssociations=yes
CloseApplications=no
RestartApplications=no
SetupLogging=yes
InfoBeforeFile={#BuildRoot}\INSTALL-NOTES.txt

[Languages]
Name: "chinesesimp"; MessagesFile: "languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildRoot}\scripts\Bootstrap.ps1"; Flags: dontcopy
Source: "{#BuildRoot}\scripts\Common.ps1"; Flags: dontcopy

[Icons]
Name: "{autodesktop}\Codex - 理世启动"; Filename: "{app}\RiseOnAir.exe"; WorkingDir: "{app}"; IconFilename: "{app}\rise-icon-v1.ico"; Comment: "理世主题与 3.2 秒有声启动动画"; AppUserModelID: "qt0713.RiseOnAir.Codex"
Name: "{group}\Codex - 理世启动"; Filename: "{app}\RiseOnAir.exe"; WorkingDir: "{app}"; IconFilename: "{app}\rise-icon-v1.ico"; AppUserModelID: "qt0713.RiseOnAir.Codex"
Name: "{group}\预览启动动画"; Filename: "{app}\RiseOnAir.exe"; Parameters: "--preview"; WorkingDir: "{app}"; IconFilename: "{app}\rise-icon-v1.ico"
Name: "{group}\理世主题管理"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ""{app}\scripts\Theme-Control.ps1"" -Action Manager"; WorkingDir: "{app}"; IconFilename: "{app}\rise-icon-v1.ico"
Name: "{group}\恢复 Codex 原始外观"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ""{app}\scripts\Theme-Control.ps1"" -Action Restore"; WorkingDir: "{app}"; IconFilename: "{app}\rise-icon-v1.ico"

[Run]
Filename: "{app}\RiseOnAir.exe"; Description: "启动 Codex 并应用理世主题"; Flags: nowait postinstall skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var ResultCode: Integer;
begin
  ExtractTemporaryFile('Bootstrap.ps1');
  ExtractTemporaryFile('Common.ps1');
  if not Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ' + AddQuotes(ExpandConstant('{tmp}\Bootstrap.ps1')) + ' -Action Preflight -InstallRoot ' + AddQuotes(ExpandConstant('{app}')),
    ExpandConstant('{tmp}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := '无法执行安装前检查。'
  else if ResultCode <> 0 then
    Result := '安装前检查失败。请确认已安装 Microsoft Store 官方 Codex，且桌面不存在不属于本项目的同名快捷方式。'
  else Result := '';
end;

function RunBootstrap(const Action: String): Boolean;
var ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ' + AddQuotes(ExpandConstant('{app}\scripts\Bootstrap.ps1')) + ' -Action ' + Action + ' -InstallRoot ' + AddQuotes(ExpandConstant('{app}')),
    ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := Result and (ResultCode = 0);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    if not RunBootstrap('Install') then
      RaiseException('主题初始化失败。请查看安装目录 logs。没有通过校验时不会标记为主题已生效。');
end;

procedure CurUninstallStepChanged(CurStep: TUninstallStep);
begin
  if CurStep = usUninstall then
    if not RunBootstrap('Uninstall') then
      RaiseException('外观恢复失败，已停止卸载以保留恢复文件。请先运行“恢复 Codex 原始外观”。');
end;
