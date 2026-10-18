[CmdletBinding()]
param([ValidateSet('Apply','Restore','Manager')][string]$Action='Apply')
. (Join-Path $PSScriptRoot 'Common.ps1')
$installRoot=Split-Path -Parent $PSScriptRoot
$record=Read-RiseIntegration -InstallRoot $installRoot
$env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
$engineScripts=Join-Path $record.stateRoot 'engine\scripts'
$logDirectory=Join-Path $installRoot 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force|Out-Null
$readyFile=Join-Path $installRoot 'LaunchReady.flag'
try {
 if($Action -eq 'Restore'){
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'restore-dream-skin.ps1'),'-RestoreBaseTheme','-PromptRestart') -LogPrefix (Join-Path $logDirectory 'restore')
 } elseif($Action -eq 'Manager'){
  & (Join-Path $engineScripts 'tray-dream-skin.ps1') -ShowWindow
 } else {
  Invoke-RiseProcess -File (Get-RisePowerShell) -Arguments @('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $engineScripts 'start-dream-skin.ps1'),'-SavedThemeDirectory',$record.themeDirectory,'-RequireUnpaused','-PromptRestart') -LogPrefix (Join-Path $logDirectory 'start')
  [IO.File]::WriteAllText($readyFile,'ready')
 }
} catch {
 $_.Exception.Message|Set-Content -LiteralPath (Join-Path $logDirectory 'last-error.txt') -Encoding UTF8
 if($Action -eq 'Apply'){
  # Upstream startup owns transactional recovery. Preserve any existing
  # verified skin session rather than forcibly removing it on wrapper errors.
  [IO.File]::WriteAllText($readyFile,'fallback')
 }
 exit 1
}
