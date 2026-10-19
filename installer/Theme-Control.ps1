[CmdletBinding()]
param([ValidateSet('Apply','Login','Restore','Manager')][string]$Action='Apply',[ValidatePattern('^[a-f0-9]{32}$')][string]$LaunchToken,[switch]$Background,[long]$NativeWindow=0)
. (Join-Path $PSScriptRoot 'Common.ps1')
$installRoot=Split-Path -Parent $PSScriptRoot
$record=Read-RiseIntegration -InstallRoot $installRoot
$env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
$engineScripts=Join-Path $record.stateRoot 'engine\scripts'
$logDirectory=Join-Path $installRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force|Out-Null
$readyFile=Join-Path $installRoot 'LaunchReady.flag'
$controlLock=$null
try {
 if($Action -ne 'Manager'){
  $controlLock=New-Object Threading.Mutex($false,'Local\RiseOnAir.ThemeControl')
  try {$acquired=$controlLock.WaitOne($(if($Background){0}else{60000}))} catch [Threading.AbandonedMutexException] {$acquired=$true}
  if(-not $acquired -and $Background){$controlLock.Dispose();$controlLock=$null;exit 0}
  if(-not $acquired){$controlLock.Dispose();$controlLock=$null;throw 'Another theme operation is still running.'}
 }
 if($Action -eq 'Restore'){
  . (Join-Path $PSScriptRoot 'Entry-Points.ps1')
  Set-RiseEntryPoints -InstallRoot $installRoot -Record $record -Remove
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'restore-dream-skin.ps1'),'-RestoreBaseTheme','-PromptRestart') -LogPrefix (Join-Path $logDirectory 'restore')
 } elseif($Action -eq 'Manager'){
  & (Join-Path $engineScripts 'tray-dream-skin.ps1') -ShowWindow
 } else {
  . (Join-Path $PSScriptRoot 'Surface-Patch.ps1')
  Set-RiseSurfaceAdapter -StateRoot $record.stateRoot -InstallRoot $installRoot
  $startArguments=@('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'start-dream-skin.ps1'),'-SavedThemeDirectory',$record.themeDirectory,'-RequireUnpaused')
  # Login is silent and never authorizes closing an existing user session.
  if($Action -ne 'Login' -and -not $Background){$startArguments+='-PromptRestart'}
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments $startArguments -LogPrefix (Join-Path $logDirectory 'start')
  # Windows upstream returns zero when its native restart prompt is cancelled.
  # Verify the current Browser ID and renderer instead of trusting that exit.
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'verify-dream-skin.ps1')) -LogPrefix (Join-Path $logDirectory 'launch-verify')
  $active=Get-Content -LiteralPath (Join-Path $record.stateRoot 'active-theme\theme.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if($active.id -ne 'p4r-rise-on-air'){throw 'The verified active theme is not Rise On Air.'}
  . (Join-Path $PSScriptRoot 'Entry-Points.ps1')
  Set-RiseWindowRelaunch -InstallRoot $installRoot -Record $record -NativeWindow $NativeWindow
  if(Test-Path -LiteralPath (Join-Path $logDirectory 'last-error.txt')){Remove-Item -LiteralPath (Join-Path $logDirectory 'last-error.txt')}
  if($LaunchToken){[IO.File]::WriteAllText($readyFile,$LaunchToken)}
 }
} catch {
 $_.Exception.Message|Set-Content -LiteralPath (Join-Path $logDirectory 'last-error.txt') -Encoding UTF8
 if($Action -in @('Apply','Login')){
  # Upstream startup owns transactional recovery. Preserve any existing
  # verified skin session rather than forcibly removing it on wrapper errors.
  if(Test-Path -LiteralPath $readyFile){Remove-Item -LiteralPath $readyFile -Force}
 }
 exit 1
} finally {
 if($controlLock){$controlLock.ReleaseMutex();$controlLock.Dispose()}
}
