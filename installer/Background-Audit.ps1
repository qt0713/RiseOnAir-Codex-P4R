. (Join-Path $PSScriptRoot 'Common.ps1')
$env:RISE_FIRST_PAINT=$null
$env:RISE_NATIVE_HANDOFF=$null
$auditLock=New-Object Threading.Mutex($false,'Local\RiseOnAir.BackgroundAudit')
$held=$false
try {
 try{$held=$auditLock.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
 if(-not $held){exit 0}
 $install=Split-Path -Parent $PSScriptRoot
 $record=Read-RiseIntegration -InstallRoot $install
 $env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
 Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $record.stateRoot 'engine\scripts\verify-dream-skin.ps1')) -LogPrefix (Join-Path $install 'logs\background-audit')
}catch{
 $_|Out-File (Join-Path $install 'logs\background-audit-failure.txt') -Encoding UTF8
 exit 1
}finally{if($held){$auditLock.ReleaseMutex()};$auditLock.Dispose()}
