param([ValidatePattern('^[a-f0-9]{32}$')][string]$LaunchToken,[ValidatePattern('^Local\\RiseOnAir\.IntroFinished\.[a-f0-9]{32}$')][string]$IntroEventName)
. (Join-Path $PSScriptRoot 'Common.ps1')
$install=Split-Path -Parent $PSScriptRoot
try {
 $record=Read-RiseIntegration -InstallRoot $install
 if(Test-Path -LiteralPath (Join-Path $record.stateRoot 'paused')){throw 'Theme is paused.'}
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
 # Reuse the upstream renderer verification in this same process. A valid
 # window alone is not sufficient; only an actually rendered Rise theme passes.
 $active=Join-Path $record.stateRoot 'active-theme'
 $theme=Get-Content -LiteralPath (Join-Path $active 'theme.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if($theme.id -ne 'p4r-rise-on-air'){throw 'Rise theme is not active.'}
 $node=Get-DreamSkinNodeRuntime
 $env:RISE_FIRST_PAINT='1'
 $env:RISE_NATIVE_HANDOFF='1'
 Invoke-RiseProcess -File $node.Path -Arguments @((Join-Path $record.stateRoot 'engine\scripts\injector.mjs'),'--verify','--port',[string]$state.port,'--browser-id',$identity.BrowserId,'--theme-dir',$active,'--timeout-ms','5000') -LogPrefix (Join-Path $install 'logs\resume-theme-verify')
 . (Join-Path $PSScriptRoot 'Entry-Points.ps1')
 try{Set-RiseWindowRelaunch -InstallRoot $install -Record $record -NativeWindow $window}catch{$_|Out-File (Join-Path $install 'logs\window-decoration-error.txt') -Encoding UTF8}
 if(-not [RiseOnAir.ResumeWindow]::IsWindowVisible([IntPtr]$window)){throw 'Main window was hidden before handoff.'}
 [IO.File]::WriteAllText((Join-Path $install ('Resume-'+$LaunchToken+'.flag')),[string]$window)
 Start-RiseBackgroundAudit -InstallRoot $install
}catch{$_|Out-File (Join-Path $install 'logs\resume-error.txt') -Encoding UTF8;exit 1}
