# Only creates our isolated profile; never closes a pre-existing Codex process.
function Ensure-RiseThemeSession {
 param([object]$Record,[string]$IntroEventName)
 . (Join-Path $Record.stateRoot 'engine\scripts\common-windows.ps1')
 . (Join-Path $Record.stateRoot 'engine\scripts\theme-windows.ps1')
 $gate=Enter-DreamSkinOperationLock -TimeoutMilliseconds 10000
 try {
  $state=Read-DreamSkinState -Path (Join-Path $Record.stateRoot 'state.json')
  . (Join-Path $PSScriptRoot 'State-Recovery.ps1')
  Repair-RiseStaleInjectorState -StateRoot $Record.stateRoot
  # Keep the port hint after archiving a dead watcher; its browser may live on.
  $preferred=if($state -and $state.port){[int]$state.port}else{9335}
  $live=Get-DreamSkinVerifiedCdpIdentityForAnyRegistered -Port $preferred
  # Let injection begin as soon as the identity-bound endpoint is available.
  # Theme-Control restores the real window after recording the new watcher.
  if($live){return $preferred}
  $codex=Get-DreamSkinCodexInstall
  $profile=Join-Path $Record.stateRoot 'cdp-profile'
  Assert-DreamSkinNoReparseComponents -Path $profile
  $before=@(Get-DreamSkinCodexProcesses -Codex $codex)
  foreach($p in $before){
   if($p.CommandLine -notmatch '--type=' -and "$($p.CommandLine)".IndexOf($profile,[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'The managed theme profile is still running without a verified listener. Save and close its window before retrying; other Codex sessions were preserved.'}
  }
  New-Item -ItemType Directory -Path $profile -Force|Out-Null
  $port=Select-DreamSkinPort -PreferredPort $preferred
  $baseline=@($before|ForEach-Object{[int]$_.ProcessId})
  $arguments=@('--remote-debugging-address=127.0.0.1',"--remote-debugging-port=$port","--user-data-dir=$profile")
  try {
   $launch=Start-DreamSkinCodexForDebugging -Codex $codex -Arguments $arguments -Port $port -PreserveProcessIds $baseline
   $deadline=[DateTime]::UtcNow.AddSeconds(45)
   do {
    $identity=Get-DreamSkinVerifiedCdpIdentity -Port $port -Codex $codex
    if($identity){return $port}
    Start-Sleep -Milliseconds 200
   }while([DateTime]::UtcNow -lt $deadline)
   throw 'A verified theme listener did not start. All pre-existing Codex processes were preserved.'
  }catch{
   # Rollback is restricted to processes absent from the pre-launch PID set.
   Stop-DreamSkinCodex -Codex $codex -PreserveProcessIds $baseline -AllowForce
   throw
  }
 }finally{Exit-DreamSkinOperationLock -Mutex $gate}
}
