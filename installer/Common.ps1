$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\Modules')+';'+$env:PSModulePath
function Invoke-RiseProcess {
 param([string]$File,[string[]]$Arguments,[string]$LogPrefix,[scriptblock]$OnPoll)
 $quoted=($Arguments|ForEach-Object{'"'+$_.Replace('"','\"')+'"'}) -join ' '
 $parameters=@{FilePath=$File;ArgumentList=$quoted;WindowStyle='Hidden';PassThru=$true}
 if($LogPrefix){$parameters.RedirectStandardOutput=$LogPrefix+'.out.log';$parameters.RedirectStandardError=$LogPrefix+'.err.log'}
 $process=Start-Process @parameters
 try {
  # Cache the native handle before waiting: Windows PowerShell may otherwise
  # lose ExitCode when a fast child has already exited. File redirection also
  # avoids waiting for EOF from a persistent injector's inherited pipes.
  $nativeHandle=$process.Handle
  if($OnPoll){while(-not $process.WaitForExit(200)){& $OnPoll}}else{$process.WaitForExit()}
  $process.Refresh()
  $exitCode=$process.ExitCode
  if($null -eq $exitCode){throw 'Child process exit status is unavailable.'}
  if($exitCode -ne 0){throw ('Process failed ('+$exitCode+'): '+[IO.Path]::GetFileName($File))}
 } finally {$process.Dispose()}
}
function Get-RisePowerShell {return (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')}
function Read-RiseIntegration {
 param([string]$InstallRoot)
 $record=Get-Content -LiteralPath (Join-Path $InstallRoot 'integration.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if($record.product -ne 'RiseOnAir' -or $record.schema -ne 1){throw 'Invalid Rise On Air installation marker.'}
 if(-not(Test-Path -LiteralPath (Join-Path $record.stateRoot 'engine\scripts\common-windows.ps1'))){throw 'Dream Skin engine is missing. Run the installer again.'}
 return $record
}
function Set-RiseEnvironment {
 param([object]$Record)
 $env:LOCALAPPDATA=Split-Path -Parent $Record.stateRoot
 . (Join-Path $Record.stateRoot 'engine\scripts\common-windows.ps1')
 . (Join-Path $Record.stateRoot 'engine\scripts\theme-windows.ps1')
}
