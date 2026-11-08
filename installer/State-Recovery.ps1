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
 # A prior-boot watcher cannot still exist, including when its recycled PID
 # belongs to a protected service whose Process.StartTime cannot be queried.
 $boot=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
 if($boot.LastBootUpTime -and $recorded.UtcDateTime -lt $boot.LastBootUpTime.ToUniversalTime()){
  $null=Archive-DreamSkinStateFile -Path $path
  return
 }
 $process=Get-Process -Id ([int]$state.injectorPid) -ErrorAction SilentlyContinue
 if(!$process){return} # Upstream already handles a missing process.
 try {
  try{$actual=$process.StartTime.ToUniversalTime()}catch{
   $info=Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$state.injectorPid) -ErrorAction Stop
   if(!$info.CreationDate){throw 'Injector creation time unavailable; state preserved.'}
   $actual=$info.CreationDate.ToUniversalTime()
  }
  # CIM timestamps have lower precision than native process timestamps.
  if([Math]::Abs(($actual-$recorded.UtcDateTime).TotalMilliseconds) -le 1){return}
  # Different creation time proves the recorded process is gone. Archive only
  # its metadata; leave the current occupant, browser and theme files alone.
  $null=Archive-DreamSkinStateFile -Path $path
 }finally{$process.Dispose()}
}
