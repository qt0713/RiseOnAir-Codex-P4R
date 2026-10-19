$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$test=Join-Path $root ('build\session-tests-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $test 'engine\scripts') -Force|Out-Null
$mock=@'
function Enter-DreamSkinOperationLock {return 'fixture-lock'}
function Exit-DreamSkinOperationLock {}
function Read-DreamSkinState {return @{port=9335}}
function Get-DreamSkinVerifiedCdpIdentityForAnyRegistered {if($global:Fixture.live){return @{Identity='fixture'}}}
function Get-DreamSkinCodexInstall {return @{Executable='registered-fixture'}}
function Get-DreamSkinCodexProcesses {return @(@{ProcessId=11;CommandLine=$global:Fixture.command})}
function Select-DreamSkinPort {return 9336}
function Start-DreamSkinCodexForDebugging {
 param($Codex,$Arguments,$Port,$PreserveProcessIds)
 $global:Fixture.launches++;$global:Fixture.preserved=@($PreserveProcessIds)
 if($global:Fixture.fail){throw 'fixture launch failure'}
 $global:Fixture.launched=$true
 return @{Strategy='fixture'}
}
function Get-DreamSkinVerifiedCdpIdentity {if($global:Fixture.launched){return @{BrowserId='new-fixture-browser'}}}
function Stop-DreamSkinCodex {
 param($Codex,$PreserveProcessIds,[switch]$AllowForce)
 $global:Fixture.rollback=@($PreserveProcessIds)
}
'@
[IO.File]::WriteAllText((Join-Path $test 'engine\scripts\common-windows.ps1'),$mock)
[IO.File]::WriteAllText((Join-Path $test 'engine\scripts\theme-windows.ps1'),'function Assert-DreamSkinNoReparseComponents {}')
Copy-Item -LiteralPath (Join-Path $root 'installer\Session-Ensure.ps1') -Destination (Join-Path $test 'Session-Ensure.ps1')
[IO.File]::WriteAllText((Join-Path $test 'Window-Resume.ps1'),'function Restore-RiseThemeWindow { $global:Fixture.restores++;return 0 }')
. (Join-Path $test 'Session-Ensure.ps1')
$record=@{stateRoot=$test}
function Reset-Fixture {$global:Fixture=@{live=$false;command='ChatGPT.exe';launches=0;launched=$false;fail=$false}}
try {
 Reset-Fixture;$global:Fixture.live=$true
 if((Ensure-RiseThemeSession $record) -ne 9335 -or $global:Fixture.launches){throw 'Live session was relaunched.'}
 Reset-Fixture
 if((Ensure-RiseThemeSession $record) -ne 9336 -or $global:Fixture.launches -ne 1 -or $global:Fixture.preserved[0] -ne 11){throw 'Stale state plus ordinary instance did not safely create a managed session.'}
 Reset-Fixture;$global:Fixture.command='ChatGPT.exe --user-data-dir='+(Join-Path $test 'cdp-profile')
 $rejected=$false;try{Ensure-RiseThemeSession $record|Out-Null}catch{$rejected=$true}
 if(!$rejected -or $global:Fixture.launches){throw 'Unverified managed session should require a clean exit, never a silent replacement.'}
 Reset-Fixture;$global:Fixture.fail=$true
 try{Ensure-RiseThemeSession $record|Out-Null}catch{}
 if($global:Fixture.rollback.Count -ne 1 -or $global:Fixture.rollback[0] -ne 11){throw 'Rollback lost the pre-existing process preservation set.'}
 'PASS live reuse / stale-session recovery with ordinary instance / unverified managed session preserved / rollback baseline preserved'
}finally{Remove-Variable Fixture -Scope Global -ErrorAction SilentlyContinue}
