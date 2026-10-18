[CmdletBinding()]
param([ValidateSet('Preflight','Install','Uninstall','Verify')][string]$Action,[string]$InstallRoot,[switch]$NoLaunch)
. (Join-Path $PSScriptRoot 'Common.ps1')
if(-not $InstallRoot){$InstallRoot=Split-Path -Parent $PSScriptRoot}
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
if($InstallRoot -eq [IO.Path]::GetPathRoot($InstallRoot)){throw 'Invalid installation root.'}
$package=Get-AppxPackage -Name OpenAI.Codex|Select-Object -First 1
if(-not $package -or $package.SignatureKind -ne 'Store'){throw '请先安装并运行 Microsoft Store 官方 Codex 客户端。'}
$codexExecutable=Join-Path $package.InstallLocation 'app\ChatGPT.exe'
function Assert-RiseShortcut {
 $path=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex - 理世启动.lnk'
 if(Test-Path -LiteralPath $path){
  $target=(New-Object -ComObject WScript.Shell).CreateShortcut($path).TargetPath
  if([IO.Path]::GetFileName($target) -ne 'RiseOnAir.exe'){throw '桌面存在同名但不属于本项目的快捷方式，请先重命名该快捷方式。'}
 }
}
if($Action -eq 'Preflight'){Assert-RiseShortcut;exit 0}
if($Action -eq 'Uninstall' -and -not(Test-Path -LiteralPath (Join-Path $InstallRoot 'integration.json'))){exit 0}
$logDirectory=Join-Path $InstallRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force|Out-Null
try {
if($Action -eq 'Install'){
 Assert-RiseShortcut
 $stateRoot=Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
 $legacyState=Join-Path ([Environment]::GetFolderPath('UserProfile')) ('AppData\Local\Packages\'+$package.PackageFamilyName+'\LocalCache\Local\CodexDreamSkin')
 if(Test-Path -LiteralPath (Join-Path $legacyState 'engine\scripts\common-windows.ps1')){$stateRoot=$legacyState}
 $env:LOCALAPPDATA=Split-Path -Parent $stateRoot
 $engineScripts=Join-Path $stateRoot 'engine\scripts'
 $setup=Join-Path $InstallRoot 'dependencies\CodexDreamSkin-Setup-v1.5.21.exe'
 if((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash -ne '80E6FB4D6E0B96DF84D5CD324D419C1CFC97ABA6E4A4B62B83B29C3F1DE62C42'){throw 'Dream Skin 安装器校验失败。'}
 # Keep an existing verified client running during package staging.
 $runtimePaths=@((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\EdgeWebView\Application'),(Join-Path $env:ProgramFiles 'Microsoft\EdgeWebView\Application'),(Join-Path $env:LOCALAPPDATA 'Microsoft\EdgeWebView\Application'))
 $runtimePresent=@($runtimePaths|Where-Object{Test-Path -LiteralPath $_}).Count -gt 0
 if(-not $runtimePresent){
  $webviewSetup=Join-Path $InstallRoot 'dependencies\MicrosoftEdgeWebview2Setup.exe'
  $signature=Get-AuthenticodeSignature -LiteralPath $webviewSetup
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike '*Microsoft Corporation*'){throw 'WebView2 安装器签名校验失败。'}
  Invoke-RiseProcess -File $webviewSetup -Arguments @('/silent','/install') -LogPrefix (Join-Path $logDirectory 'webview2')
 }
 $versionFile=Join-Path $stateRoot 'engine\VERSION'
 $installedVersion=if(Test-Path -LiteralPath $versionFile){[IO.File]::ReadAllText($versionFile).Trim()}else{''}
 if($installedVersion -ne '1.5.21'){
  Invoke-RiseProcess -File $setup -Arguments @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR='+ (Join-Path $InstallRoot 'dependencies\DreamSkin'))) -LogPrefix (Join-Path $logDirectory 'dependency')
 }
 . (Join-Path $engineScripts 'common-windows.ps1')
 . (Join-Path $engineScripts 'theme-windows.ps1')
 . (Join-Path $PSScriptRoot 'Surface-Patch.ps1')
 Set-RiseSurfaceAdapter -StateRoot $stateRoot -InstallRoot $InstallRoot
 $imported=Import-DreamSkinThemeZip -ArchivePath (Join-Path $InstallRoot 'theme.zip') -StateRoot $stateRoot
 $record=[ordered]@{product='RiseOnAir';schema=1;version='1.0.2';stateRoot=$stateRoot;themeDirectory=$imported.Path;codexPackageFamily=$package.PackageFamilyName;installedUtc=[DateTime]::UtcNow.ToString('o')}
 [IO.File]::WriteAllText((Join-Path $InstallRoot 'integration.json'),($record|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
 $appId=$package.PackageFamilyName+'!App'
 [IO.File]::WriteAllText((Join-Path $InstallRoot 'CodexAppId.txt'),$appId)
 Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class RiseShellRefresh { [DllImport("shell32.dll",CharSet=CharSet.Unicode)] public static extern void SHChangeNotify(uint e,uint f,string p,IntPtr q); }'
 [RiseShellRefresh]::SHChangeNotify(0x08000000,0,$null,[IntPtr]::Zero)
} elseif($Action -eq 'Uninstall'){
 $record=Read-RiseIntegration -InstallRoot $InstallRoot
 $env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
 Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $record.stateRoot 'engine\scripts\restore-dream-skin.ps1'),'-RestoreBaseTheme','-ForceRestart') -LogPrefix (Join-Path $logDirectory 'uninstall-restore')
 . (Join-Path $PSScriptRoot 'Surface-Patch.ps1')
 Set-RiseSurfaceAdapter -StateRoot $record.stateRoot -InstallRoot $InstallRoot -Remove
} else {
 $record=Read-RiseIntegration -InstallRoot $InstallRoot
 $env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
 Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $record.stateRoot 'engine\scripts\verify-dream-skin.ps1')) -LogPrefix (Join-Path $logDirectory 'verify')
}
} catch {
 [IO.File]::WriteAllText((Join-Path $logDirectory 'bootstrap-error.txt'),($_|Out-String))
 throw
}
