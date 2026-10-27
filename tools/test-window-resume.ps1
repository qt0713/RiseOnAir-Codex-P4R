$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$fixture=Join-Path $root ('build\resume-contract-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $fixture 'logs') -Force|Out-Null
Add-Type 'namespace RiseOnAir { public static class ResumeWindow { public static long Restore(int p,double x,double y,double w,double h,double d) {return 42;} public static bool IsWindowVisible(System.IntPtr h){return h.ToInt64()==42;} } }'
function Get-DreamSkinPortListeners {return @{OwningProcess=10}}
function Get-DreamSkinNodeRuntime {return @{Path='fixture'}}
function Get-DreamSkinVerifiedCdpIdentity {return @{BrowserId='fixture-browser'}}
function Invoke-RiseProcess {
 param($File,$Arguments,$LogPrefix)
 if($Arguments[0] -like '*window-capability.mjs'){@{schema=1;resume=$script:supported}|ConvertTo-Json|Set-Content ($LogPrefix+'.out.log');return}
 if($Arguments[-1] -eq 'show'){$script:shows++;$script:visibility='visible'}
 @{x=0;y=0;width=1280;height=720;dpr=1;visibility=$script:visibility}|ConvertTo-Json|Set-Content ($LogPrefix+'.out.log')
}
. (Join-Path $root 'installer\Window-Resume.ps1')
foreach($supported in @($true,$false)){
 $script:supported=$supported
 $script:visibility='visible';$script:shows=0
 $window=Restore-RiseThemeWindow -Record @{} -Codex @{Executable='C:\fixture\ChatGPT.exe'} -Identity @{BrowserId='fixture-browser'} -Port 9335 -InstallRoot $fixture -ShowForHandoff
 if($window -ne 42){throw 'Visible window rejected.'}
 if(-not $supported -and $script:shows){throw 'Unreviewed private IPC used.'}
}
$script:supported=$true;$script:visibility='hidden';$script:shows=0
$window=Restore-RiseThemeWindow -Record @{} -Codex @{Executable='C:\fixture\ChatGPT.exe'} -Identity @{BrowserId='fixture-browser'} -Port 9335 -InstallRoot $fixture
if($window -ne 42 -or $script:shows -ne 1){throw 'Reviewed new version did not restore hidden window.'}
$script:supported=$false;$script:visibility='hidden';$script:shows=0;$rejected=$false
try{Restore-RiseThemeWindow -Record @{} -Codex @{Executable='C:\fixture\ChatGPT.exe'} -Identity @{BrowserId='fixture-browser'} -Port 9335 -InstallRoot $fixture}catch{$rejected=$true}
if(-not $rejected -or $script:shows){throw 'Unknown hidden-window protocol was not rejected.'}
'PASS current/previous/future visible windows; reviewed hidden resume; unknown hidden IPC rejected.'
