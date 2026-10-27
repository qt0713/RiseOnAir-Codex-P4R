# Run in an interactive desktop session after tools/build.ps1, with Codex open.
# Forces failure only in a disposable copy, never in the installed theme.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$stage=Join-Path $root 'build\payload'
$fixture=Join-Path $root ('build\fallback-test-'+[guid]::NewGuid().ToString('N'))
$before=@(Get-Process ChatGPT -ErrorAction Stop|Select-Object -ExpandProperty Id)
if(-not @(Get-Process ChatGPT|Where-Object{$_.MainWindowHandle -ne 0}).Count){throw 'Open the existing Codex window before this test.'}
New-Item -ItemType Directory -Path $fixture,(Join-Path $fixture 'scripts') -Force|Out-Null
Get-ChildItem -LiteralPath $stage|Where-Object{$_.Name -notin @('dependencies','runtime','scripts','launcher.log')}|ForEach-Object{Copy-Item -LiteralPath $_.FullName -Destination $fixture -Recurse}
[IO.File]::WriteAllText((Join-Path $fixture 'scripts\Resume-Session.ps1'),'exit 1')
[IO.File]::WriteAllText((Join-Path $fixture 'scripts\Theme-Control.ps1'),'exit 1')
[IO.File]::WriteAllText((Join-Path $fixture 'integration.json'),'{}')
$timer=[Diagnostics.Stopwatch]::StartNew()
$process=Start-Process -FilePath (Join-Path $fixture 'RiseOnAir.exe') -ArgumentList '--muted' -WindowStyle Hidden -PassThru
if(-not $process.WaitForExit(30000)){throw 'Failed theme left the intro running.'}
$log=[IO.File]::ReadAllText((Join-Path $fixture 'launcher.log'))
if($log -notmatch 'official-fallback theme-unverified' -or $log -notmatch 'handoff-official-fallback' -or (Test-Path (Join-Path $fixture 'LaunchReady.flag'))){throw 'Failure was not explicitly handed off without claiming theme readiness.'}
$after=@(Get-Process ChatGPT|Select-Object -ExpandProperty Id)
if(@($before|Where-Object{$_ -notin $after}).Count){throw 'An existing client process exited.'}
@{pass=$true;seconds=$timer.Elapsed.TotalSeconds;fallbackExplicit=$true;clientsPreserved=$true}|ConvertTo-Json
