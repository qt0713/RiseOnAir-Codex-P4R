param([ValidatePattern('^[a-f0-9]{32}$')][string]$LaunchToken,[ValidatePattern('^Local\\RiseOnAir\.IntroFinished\.[a-f0-9]{32}$')][string]$IntroEventName)
. (Join-Path $PSScriptRoot 'Common.ps1')
$install=Split-Path -Parent $PSScriptRoot
try {
 $record=Read-RiseIntegration -InstallRoot $install
 $env:LOCALAPPDATA=Split-Path -Parent $record.stateRoot
 . (Join-Path $record.stateRoot 'engine\scripts\common-windows.ps1')
 $state=Read-DreamSkinState -Path (Join-Path $record.stateRoot 'state.json')
 if(!$state){throw 'No saved theme session.'}
 $codex=Get-DreamSkinCodexInstallFromState -State $state
 if(!$codex){throw 'Saved package is not registered.'}
 $identity=Get-DreamSkinVerifiedCdpIdentity -Port $state.port -Codex $codex
 if(!$identity -or $identity.BrowserId -cne $state.browserId){throw 'Theme session identity changed.'}
 . (Join-Path $PSScriptRoot 'Window-Resume.ps1')
 $window=Restore-RiseThemeWindow -Record $record -Codex $codex -Identity $identity -Port $state.port -InstallRoot $install -IntroEventName $IntroEventName
 . (Join-Path $PSScriptRoot 'Entry-Points.ps1')
 try{Set-RiseWindowRelaunch -InstallRoot $install -Record $record -NativeWindow $window}catch{$_|Out-File (Join-Path $install 'logs\window-decoration-error.txt') -Encoding UTF8}
 [IO.File]::WriteAllText((Join-Path $install ('Resume-'+$LaunchToken+'.flag')),[string]$window)
}catch{$_|Out-File (Join-Path $install 'logs\resume-error.txt') -Encoding UTF8;exit 1}
