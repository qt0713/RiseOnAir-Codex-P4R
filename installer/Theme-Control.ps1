[CmdletBinding()]
param([ValidateSet('Apply','Login','Restore','Manager')][string]$Action='Apply',[ValidatePattern('^[a-f0-9]{32}$')][string]$LaunchToken,[switch]$Background,[long]$NativeWindow=0,[switch]$EnsureSession,[ValidatePattern('^Local\\RiseOnAir\.IntroFinished\.[a-f0-9]{32}$')][string]$IntroEventName)
. (Join-Path $PSScriptRoot 'Common.ps1')
$installRoot=Split-Path -Parent $PSScriptRoot
$record=Read-RiseIntegration -InstallRoot $installRoot
$env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
$engineScripts=Join-Path $record.stateRoot 'engine\scripts'
$logDirectory=Join-Path $installRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force|Out-Null
function Write-LaunchPhase([string]$Phase){[IO.File]::AppendAllText((Join-Path $logDirectory 'startup-phases.log'),([DateTime]::UtcNow.ToString('o')+' token='+$LaunchToken+' '+$Phase+[Environment]::NewLine))}
Write-LaunchPhase 'begin'
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
  $sessionPort=$null
  if($EnsureSession){Write-LaunchPhase 'ensure-session';. (Join-Path $PSScriptRoot 'Session-Ensure.ps1');$sessionPort=Ensure-RiseThemeSession -Record $record -IntroEventName $IntroEventName;Write-LaunchPhase 'session-restored'}
  . (Join-Path $PSScriptRoot 'Surface-Patch.ps1')
  Set-RiseSurfaceAdapter -StateRoot $record.stateRoot -InstallRoot $installRoot
  $reuseTheme=$false
  try{
   . (Join-Path $engineScripts 'common-windows.ps1')
   . (Join-Path $engineScripts 'theme-windows.ps1')
   $activeFingerprint=Get-DreamSkinThemeRuntimeContentFingerprint -ThemeDirectory (Join-Path $record.stateRoot 'active-theme')
   $savedFingerprint=Get-DreamSkinThemeRuntimeContentFingerprint -ThemeDirectory $record.themeDirectory
   $reuseTheme=$activeFingerprint -and $activeFingerprint -ceq $savedFingerprint
  }catch{$reuseTheme=$false}
  $startArguments=@('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'start-dream-skin.ps1'),'-RequireUnpaused')
  if(-not $reuseTheme){$startArguments+=@('-SavedThemeDirectory',$record.themeDirectory)}
  Write-LaunchPhase ('reuse-theme-content='+$reuseTheme)
  # Login is silent and never authorizes closing an existing user session.
  if($sessionPort){$startArguments+=@('-Port',[string]$sessionPort)}
  if($Action -ne 'Login' -and -not $Background -and -not $EnsureSession){$startArguments+='-PromptRestart'}
  $alreadyVerified=$false
  if($NativeWindow -ne 0){
   try{
    $active=Get-Content -LiteralPath (Join-Path $record.stateRoot 'active-theme\theme.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if($active.id -eq 'p4r-rise-on-air'){
     Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'verify-dream-skin.ps1')) -LogPrefix (Join-Path $logDirectory 'launch-verify')
     $alreadyVerified=$true
    }
   }catch{$alreadyVerified=$false}
  }
  if(-not $alreadyVerified){
  Write-LaunchPhase 'apply-theme'
  $onStarted=$null
  if($sessionPort){
   $prior=Read-DreamSkinState -Path (Join-Path $record.stateRoot 'state.json')
   $handoff=@{done=$false;generation="$($prior.createdAt)"}
   $onStarted={try{
    if(-not $handoff.done){
     $now=Read-DreamSkinState -Path (Join-Path $record.stateRoot 'state.json')
     if($now -and "$($now.createdAt)" -ne $handoff.generation){
      $handoff.done=$true
      $live=Get-DreamSkinVerifiedCdpIdentityForAnyRegistered -Port $sessionPort
      if(!$live -or $live.Identity.BrowserId -cne $now.browserId){throw 'Theme session changed before final window handoff.'}
      . (Join-Path $PSScriptRoot 'Window-Resume.ps1')
      $handoff.window=Restore-RiseThemeWindow -Record $record -Codex $live.Codex -Identity $live.Identity -Port $sessionPort -InstallRoot $installRoot -IntroEventName $IntroEventName -ShowForHandoff
      Write-LaunchPhase 'injector-ready-window-restored'
     }
    }
   }catch{$handoff.done=$true;Write-LaunchPhase ('window-handoff-failed '+$_.Exception.Message)}}
  }
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments $startArguments -LogPrefix (Join-Path $logDirectory 'start') -OnPoll $onStarted
  Write-LaunchPhase 'verify-theme'
  # Windows upstream returns zero when its native restart prompt is cancelled.
  # Verify the current Browser ID and renderer instead of trusting that exit.
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-NonInteractive','-WindowStyle','Hidden','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'verify-dream-skin.ps1')) -LogPrefix (Join-Path $logDirectory 'launch-verify')
  }
  $active=Get-Content -LiteralPath (Join-Path $record.stateRoot 'active-theme\theme.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if($active.id -ne 'p4r-rise-on-air'){throw 'The verified active theme is not Rise On Air.'}
  . (Join-Path $PSScriptRoot 'Entry-Points.ps1')
  if($sessionPort -and $handoff.window){$NativeWindow=[long]$handoff.window}
  try{Set-RiseWindowRelaunch -InstallRoot $installRoot -Record $record -NativeWindow $NativeWindow}catch{$_|Out-File (Join-Path $logDirectory 'window-decoration-error.txt') -Encoding UTF8}
  if(Test-Path -LiteralPath (Join-Path $logDirectory 'last-error.txt')){Remove-Item -LiteralPath (Join-Path $logDirectory 'last-error.txt')}
  if($LaunchToken){
   if($sessionPort -and $handoff.window){[IO.File]::WriteAllText((Join-Path $installRoot ('LaunchWindow-'+$LaunchToken+'.flag')),[string]$handoff.window)}
   [IO.File]::WriteAllText($readyFile,$LaunchToken)
  }
  Write-LaunchPhase 'ready'
 }
} catch {
 Write-LaunchPhase ('failed '+$_.Exception.Message)
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
