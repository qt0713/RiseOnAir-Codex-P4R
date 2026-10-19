[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$test=Join-Path $root ('build\entry-tests-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $test,(Join-Path $test 'scripts'),(Join-Path $test 'state\engine\scripts'),(Join-Path $test 'state\active-theme') -Force|Out-Null
$utf8=New-Object Text.UTF8Encoding($true)
function Write-TestFile([string]$Name,[string]$Text){[IO.File]::WriteAllText((Join-Path $test $Name),$Text,$utf8)}
foreach($f in @('Common.ps1','Theme-Control.ps1','ShellIdentity.cs')){Copy-Item -LiteralPath (Join-Path $root ('installer\'+$f)) -Destination (Join-Path $test 'scripts')}
Write-TestFile 'scripts\Surface-Patch.ps1' 'function Set-RiseSurfaceAdapter {}'
Write-TestFile 'scripts\Entry-Points.ps1' 'function Set-RiseWindowRelaunch {}'
Write-TestFile 'state\engine\scripts\common-windows.ps1' '# fixture identity marker'
Write-TestFile 'state\engine\scripts\start-dream-skin.ps1' 'exit 0 # upstream restart cancellation'
$record=@{product='RiseOnAir';schema=1;stateRoot=(Join-Path $test 'state');themeDirectory='fixture'}
Write-TestFile 'integration.json' ($record|ConvertTo-Json)
Write-TestFile 'state\active-theme\theme.json' '{"id":"p4r-rise-on-air"}'
Write-TestFile 'state\engine\scripts\verify-dream-skin.ps1' 'exit 1'
Write-TestFile 'LaunchReady.flag' 'stale-old-session'
$ps=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$token='0123456789abcdef0123456789abcdef'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token
if($LASTEXITCODE -eq 0 -or (Test-Path (Join-Path $test 'LaunchReady.flag'))){throw 'Cancelled/unverified session must not report ready.'}
Write-TestFile 'state\engine\scripts\verify-dream-skin.ps1' 'exit 0'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token
if($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText((Join-Path $test 'LaunchReady.flag')) -cne $token){throw 'Verified readiness must match this launch token.'}
# A healthy resumed renderer is verified without reinstalling its theme.
Write-TestFile 'state\engine\scripts\start-dream-skin.ps1' 'exit 77'
Write-TestFile 'scripts\Entry-Points.ps1' 'function Set-RiseWindowRelaunch {throw "Cosmetic shell property failure"}'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token -NativeWindow 1
if($LASTEXITCODE -ne 0){throw 'Healthy resume must skip reapply and tolerate cosmetic icon errors.'}
Write-TestFile 'state\engine\scripts\verify-dream-skin.ps1' 'exit 1'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token -NativeWindow 1
if($LASTEXITCODE -eq 0 -or (Test-Path (Join-Path $test 'LaunchReady.flag'))){throw 'An unverified resumed window must not report success.'}
Write-TestFile 'state\engine\scripts\verify-dream-skin.ps1' 'exit 0'
Write-TestFile 'state\engine\scripts\start-dream-skin.ps1' 'exit 0'
Write-TestFile 'state\active-theme\theme.json' '{"id":"different-theme"}'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token
if($LASTEXITCODE -eq 0 -or (Test-Path (Join-Path $test 'LaunchReady.flag'))){throw 'Wrong theme must not report ready.'}
Write-TestFile 'state\active-theme\theme.json' '{"id":"p4r-rise-on-air"}'
Write-TestFile 'state\engine\scripts\theme-windows.ps1' 'function Get-DreamSkinThemeRuntimeContentFingerprint {param($ThemeDirectory) return "same-content"}'
Write-TestFile 'state\engine\scripts\start-dream-skin.ps1' 'param([string]$SavedThemeDirectory,[switch]$RequireUnpaused) if($SavedThemeDirectory){exit 78};exit 0'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token
if($LASTEXITCODE -ne 0){throw 'Identical theme content must skip reimport.'}
Write-TestFile 'state\engine\scripts\theme-windows.ps1' 'function Get-DreamSkinThemeRuntimeContentFingerprint {param($ThemeDirectory) return $ThemeDirectory}'
Write-TestFile 'state\engine\scripts\start-dream-skin.ps1' 'param([string]$SavedThemeDirectory,[switch]$RequireUnpaused) if($SavedThemeDirectory -ne "fixture"){exit 79};exit 0'
& $ps -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File (Join-Path $test 'scripts\Theme-Control.ps1') -LaunchToken $token
if($LASTEXITCODE -ne 0){throw 'Changed theme content must still select the saved theme.'}
Add-Type -Path (Join-Path $root 'installer\ShellIdentity.cs')
$shortcut=Join-Path $test 'Property store test.lnk'
$link=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
$link.TargetPath=$ps;$link.Save()
[RiseOnAir.ShellIdentity]::Write($shortcut,0,5,'RiseOnAir.Test')
if([RiseOnAir.ShellIdentity]::Read($shortcut,0,5) -cne 'RiseOnAir.Test'){throw 'Shortcut AppUserModelID round trip failed.'}
. (Join-Path $root 'installer\Entry-Points.ps1')
# Restore a legacy wrapper pin in a workspace fixture, without touching real pins.
function Set-RiseWindowRelaunch {}
function Get-AppxPackage {return [pscustomobject]@{InstallLocation=(Join-Path $test 'official')}}
function Get-ItemPropertyValue {return $null}
$link.TargetPath=Join-Path $test 'RiseOnAir.exe';$link.Save()
$backup=Join-Path $test 'original.lnk';Copy-Item -LiteralPath $shortcut -Destination $backup
$entry=@{schema=1;shortcuts=@(@{path=$shortcut;backup=$backup;managedHash=(Get-FileHash -LiteralPath $shortcut).Hash})}
Write-TestFile 'entry-points.json' ($entry|ConvertTo-Json -Depth 5)
Set-RiseEntryPoints -InstallRoot $test -Record @{codexPackageFamily='OpenAI.Codex_Test'} -Remove
$restored=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
if($restored.TargetPath -ine (Join-Path $test 'official\app\ChatGPT.exe')){throw 'Restored legacy pin must not point at the removed wrapper.'}
@{cancelledStartRejected=$true;staleReadinessRejected=$true;launchTokenBound=$true;wrongThemeRejected=$true;shellIdentityRoundTrip=$true;legacyPinRestore=$true}|ConvertTo-Json
