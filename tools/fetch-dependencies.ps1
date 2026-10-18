$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$dependencies=Join-Path $root 'dependencies'
$cache=Join-Path $root '.cache\webview'
New-Item -ItemType Directory -Path $dependencies,$cache -Force|Out-Null
$dreamSkin=Join-Path $dependencies 'CodexDreamSkin-Setup-v1.5.21.exe'
if(-not(Test-Path -LiteralPath $dreamSkin)){Invoke-WebRequest -Uri 'https://github.com/Fei-Away/Codex-Dream-Skin/releases/download/v1.5.21/CodexDreamSkin-Setup-v1.5.21.exe' -OutFile $dreamSkin}
if((Get-FileHash -LiteralPath $dreamSkin -Algorithm SHA256).Hash -ne '80E6FB4D6E0B96DF84D5CD324D419C1CFC97ABA6E4A4B62B83B29C3F1DE62C42'){throw 'Dream Skin SHA-256 mismatch.'}
$bootstrapper=Join-Path $dependencies 'MicrosoftEdgeWebview2Setup.exe'
if(-not(Test-Path -LiteralPath $bootstrapper)){Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $bootstrapper}
$signature=Get-AuthenticodeSignature -LiteralPath $bootstrapper
if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike '*Microsoft Corporation*'){throw 'Invalid Microsoft WebView2 bootstrapper signature.'}
$package=Join-Path $cache 'sdk.nupkg'
if(-not(Test-Path -LiteralPath $package)){Invoke-WebRequest -Uri 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.4258.31/microsoft.web.webview2.1.0.4258.31.nupkg' -OutFile $package}
if((Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash -ne '56F7F4B8BF9AEE4B8EFEFBBDD4F67D5F74EBD1B100ED0806DA71BF76AF481AA9'){throw 'WebView2 SDK SHA-256 mismatch.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($package)
try {
 $files=@{'lib/net462/Microsoft.Web.WebView2.Core.dll'='Microsoft.Web.WebView2.Core.dll';'lib/net462/Microsoft.Web.WebView2.Wpf.dll'='Microsoft.Web.WebView2.Wpf.dll';'runtimes/win-x64/native/WebView2Loader.dll'='WebView2Loader.dll';'LICENSE.txt'='Microsoft.WebView2.LICENSE.txt';'NOTICE.txt'='Microsoft.WebView2.NOTICE.txt'}
 foreach($item in $files.GetEnumerator()){
  $entry=$zip.GetEntry($item.Key);if(-not $entry){throw ('Missing SDK file: '+$item.Key)}
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $cache $item.Value),$true)
 }
} finally {$zip.Dispose()}
Write-Output 'Pinned dependencies verified and ready.'
