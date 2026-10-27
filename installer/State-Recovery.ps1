# Caller holds the upstream operation mutex. Never terminate a PID based on an
# old record: Windows can assign it to an unrelated process after reboot.
function Repair-RiseStaleInjectorState {
 param([string]$StateRoot)
 $path=Join-Path $StateRoot 'state.json'
 Assert-DreamSkinNoReparseComponents -Path $path
 $state=Read-DreamSkinState -Path $path
 if(!$state -or !$state.injectorPid -or !$state.injectorStartedAt){return}
 $recorded=[DateTimeOffset]::MinValue
 if(-not [DateTimeOffset]::TryParse([string]$state.injectorStartedAt,[ref]$recorded)){throw 'Invalid recorded injector creation time; state preserved.'}
 $process=Get-Process -Id ([int]$state.injectorPid) -ErrorAction SilentlyContinue
 if(!$process){return} # Upstream already handles a missing process.
 try {
  try{$actual=$process.StartTime.ToUniversalTime()}catch{throw 'Injector creation time unavailable; state preserved.'}
  if($actual.Ticks -eq $recorded.UtcDateTime.Ticks){return}
  # Different creation time proves the recorded process is gone. Archive only
  # its metadata; leave the current occupant, browser and theme files alone.
  $null=Archive-DreamSkinStateFile -Path $path
 }finally{$process.Dispose()}
}
