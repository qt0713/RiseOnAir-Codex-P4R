$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'installer\State-Recovery.ps1')
$fixture=Join-Path (Split-Path -Parent $PSScriptRoot) ('build\state-recovery-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force|Out-Null
function Assert-DreamSkinNoReparseComponents {param($Path)}
function Read-DreamSkinState {param($Path) Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
function Archive-DreamSkinStateFile {param($Path) Move-Item -LiteralPath $Path -Destination ($Path+'.archived')}
$path=Join-Path $fixture 'state.json'
$started=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
@{injectorPid=$PID;injectorStartedAt=$started}|ConvertTo-Json|Set-Content $path
Repair-RiseStaleInjectorState -StateRoot $fixture
if(-not(Test-Path $path)){throw 'Live generation was archived.'}
@{injectorPid=$PID;injectorStartedAt='2000-01-01T00:00:00Z'}|ConvertTo-Json|Set-Content $path
Repair-RiseStaleInjectorState -StateRoot $fixture
if((Test-Path $path) -or -not(Test-Path ($path+'.archived'))){throw 'Reused PID record was not archived.'}
if(-not(Get-Process -Id $PID)){throw 'Unrelated process was stopped.'}
@{injectorPid=$PID;injectorStartedAt='invalid'}|ConvertTo-Json|Set-Content $path
$rejected=$false
try{Repair-RiseStaleInjectorState -StateRoot $fixture}catch{$rejected=$true}
if(-not $rejected -or -not(Test-Path $path)){throw 'Ambiguous metadata was not preserved.'}
# Archiving a watcher must not lose a non-default live browser port.
New-Item -ItemType Directory -Path (Join-Path $fixture 'engine\scripts') -Force|Out-Null
foreach($name in @('common-windows.ps1','theme-windows.ps1')){[IO.File]::WriteAllText((Join-Path $fixture ('engine\scripts\'+$name)),'# fixture')}
function Enter-DreamSkinOperationLock {return 'fixture-lock'}
function Exit-DreamSkinOperationLock {}
function Get-DreamSkinVerifiedCdpIdentityForAnyRegistered {param($Port) if($Port -ne 9444){throw 'Lost non-default browser port.'};return @{live=$true}}
function Archive-DreamSkinStateFile {param($Path) Move-Item -LiteralPath $Path -Destination ($Path+'.port-test-archived')}
@{injectorPid=$PID;injectorStartedAt='2000-01-01T00:00:00Z';port=9444}|ConvertTo-Json|Set-Content $path
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'installer\Session-Ensure.ps1')
if((Ensure-RiseThemeSession -Record @{stateRoot=$fixture}) -ne 9444){throw 'Existing browser port was not reused.'}
'PASS live generation preserved; recycled PID metadata archived without terminating its occupant; invalid time rejected.'
