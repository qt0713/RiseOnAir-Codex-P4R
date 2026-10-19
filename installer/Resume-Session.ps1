param([ValidatePattern('^[a-f0-9]{32}$')][string]$LaunchToken)
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
 $listeners=@(Get-DreamSkinPortListeners -Port $state.port)
 $owners=@($listeners.OwningProcess|Sort-Object -Unique)
 if($owners.Count -ne 1){throw 'Ambiguous theme browser owner.'}
 $node=Get-DreamSkinNodeRuntime
 $prefix=Join-Path $install ('logs\resume-'+$LaunchToken)
 Invoke-RiseProcess -File $node.Path -Arguments @((Join-Path $install 'runtime\resume-window.mjs'),[string]$state.port,$state.browserId) -LogPrefix $prefix
 $bounds=Get-Content -LiteralPath ($prefix+'.out.log') -Raw -Encoding UTF8|ConvertFrom-Json
 # Revalidate after reading geometry, before operating on the native window.
 $latest=Get-DreamSkinVerifiedCdpIdentity -Port $state.port -Codex $codex
 if(!$latest -or $latest.BrowserId -cne $identity.BrowserId){throw 'Theme session changed during resume.'}
 Add-Type -Path (Join-Path $PSScriptRoot 'ResumeWindow.cs')
 $window=[RiseOnAir.ResumeWindow]::Restore($owners[0],$bounds.x,$bounds.y,$bounds.width,$bounds.height,$bounds.dpr)
 $handle=[IntPtr]$window
 $limit=[DateTime]::UtcNow.AddSeconds(3)
 while(-not [RiseOnAir.ResumeWindow]::IsWindowVisible($handle) -and [DateTime]::UtcNow -lt $limit){Start-Sleep -Milliseconds 50}
 if(-not [RiseOnAir.ResumeWindow]::IsWindowVisible($handle)){throw 'Main window did not become visible.'}
 [IO.File]::WriteAllText((Join-Path $install ('Resume-'+$LaunchToken+'.flag')),[string]$window)
}catch{$_|Out-File (Join-Path $install 'logs\resume-error.txt') -Encoding UTF8;exit 1}
