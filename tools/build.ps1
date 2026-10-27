[CmdletBinding()]
param([string]$Compiler,[switch]$StageOnly)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$stage=Join-Path $root 'build\payload'
$output=Join-Path $root 'dist'
if(Test-Path -LiteralPath $stage){
 $expectedStage=[IO.Path]::GetFullPath((Join-Path $root 'build\payload'))
 if([IO.Path]::GetFullPath($stage) -ne $expectedStage -or ((Get-Item -LiteralPath $stage).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Unsafe staging directory.'}
 Remove-Item -LiteralPath $expectedStage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage,$output,(Join-Path $stage 'scripts'),(Join-Path $stage 'dependencies') -Force|Out-Null
Copy-Item -Path (Join-Path $root 'src\animation\*') -Destination $stage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'assets\rise-on-air-icon-v2.ico') -Destination (Join-Path $stage 'rise-icon-v1.ico') -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE'),(Join-Path $root 'THIRD_PARTY_NOTICES.md') -Destination $stage -Force
Copy-Item -LiteralPath (Join-Path $root 'src\runtime') -Destination $stage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'licenses') -Destination $stage -Recurse -Force
foreach($file in @('Common.ps1','Theme-Control.ps1','Bootstrap.ps1','Surface-Patch.ps1','Entry-Points.ps1','ShellIdentity.cs','Resume-Session.ps1','ResumeWindow.cs','Session-Ensure.ps1','State-Recovery.ps1','Window-Resume.ps1','Background-Audit.ps1')){
 $text=[IO.File]::ReadAllText((Join-Path $root ('installer\'+$file)))
 [IO.File]::WriteAllText((Join-Path $stage ('scripts\'+$file)),$text,(New-Object Text.UTF8Encoding($true)))
}
$webview=Join-Path $root '.cache\webview'
foreach($file in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.Wpf.dll','WebView2Loader.dll','Microsoft.WebView2.LICENSE.txt','Microsoft.WebView2.NOTICE.txt')){
 Copy-Item -LiteralPath (Join-Path $webview $file) -Destination $stage -Force
}
Copy-Item -LiteralPath (Join-Path $root 'dependencies\CodexDreamSkin-Setup-v1.5.21.exe') -Destination (Join-Path $stage 'dependencies') -Force
Copy-Item -LiteralPath (Join-Path $root 'dependencies\MicrosoftEdgeWebview2Setup.exe') -Destination (Join-Path $stage 'dependencies') -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$themeZip=Join-Path $stage 'theme.zip'
if(Test-Path -LiteralPath $themeZip){Remove-Item -LiteralPath $themeZip}
[IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $root 'src\theme'),$themeZip)
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$arguments=@('/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+(Join-Path $stage 'RiseOnAir.exe')),('/win32manifest:'+(Join-Path $root 'src\launcher\app.manifest')),('/win32icon:'+(Join-Path $stage 'rise-icon-v1.ico')))
foreach($file in @('PresentationFramework.dll','PresentationCore.dll','WindowsBase.dll')){$arguments+=('/reference:'+(Join-Path $framework ('WPF\'+$file)))}
foreach($file in @('System.Xaml.dll','System.Windows.Forms.dll','System.Drawing.dll','System.Management.dll')){$arguments+=('/reference:'+(Join-Path $framework $file))}
foreach($file in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.Wpf.dll')){$arguments+=('/reference:'+(Join-Path $stage $file))}
& (Join-Path $framework 'csc.exe') @arguments (Join-Path $root 'src\launcher\RiseOnAir.cs') (Join-Path $root 'src\launcher\WebLaunchWindow.cs') (Join-Path $root 'src\launcher\WindowPlacement.cs') (Join-Path $root 'src\launcher\CodexSession.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher compile failed.'}
& (Join-Path $framework 'csc.exe') '/nologo' '/target:winexe' '/platform:x64' '/optimize+' ('/out:'+(Join-Path $stage 'RiseIconBridge.exe')) (Join-Path $root 'src\launcher\IconBridge.cs')
if($LASTEXITCODE -ne 0){throw 'Icon bridge compile failed.'}
Copy-Item -LiteralPath (Join-Path $root 'src\launcher\RiseOnAir.exe.config') -Destination $stage -Force
'OpenAI.Codex_2p2nqsd0c76g0!App'|Set-Content -LiteralPath (Join-Path $stage 'CodexAppId.txt') -Encoding ascii
$notes="Rise On Air · 理世主题`r`n`r`n安装会关闭 Codex，请先保存未发送的输入。`r`n包含本地主题、3.2 秒有声启动动画、理世快捷方式和恢复入口。`r`n这是个人同人项目，不是 ATLUS、SEGA 或 OpenAI 官方产品。`r`n官方客户端更新后，第三方主题可能需要更新；若加载失败将恢复普通外观。`r`n安装不会改动 WindowsApps、应用签名或 API 提供商配置。"
[IO.File]::WriteAllText((Join-Path $stage 'INSTALL-NOTES.txt'),$notes,(New-Object Text.UTF8Encoding($true)))
if($StageOnly){Write-Output $stage;exit 0}
if(-not $Compiler){$Compiler=Join-Path $root '.cache\inno\ISCC.exe'}
& $Compiler ('/DBuildRoot='+$stage) ('/DOutputRoot='+$output) (Join-Path $root 'installer\RiseOnAir.iss')
if($LASTEXITCODE -ne 0){throw 'Installer compilation failed.'}
$installer=Join-Path $output 'RiseOnAir-Setup-v1.0.9-windows-x64.exe'
$hash=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
($hash+'  '+[IO.Path]::GetFileName($installer))|Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
Write-Output $installer
