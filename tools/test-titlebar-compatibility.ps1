Import-Module Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\installer\Surface-Patch.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('rise-titlebar-test-'+[guid]::NewGuid().ToString('N'))
$assets=Join-Path $root 'engine\assets'
New-Item -ItemType Directory -Path $assets -Force|Out-Null
$fixtureOriginal='header:is(.app-header-tint, [data-app-shell-header-edge-scroll], [class*="_Header_"])'
$fixtureHashes=@{
 'selectors.json'='939217A45F6502B9939A23F8EB6D1E766D306A94F462ADFE38D9D50D0C191873'
 'renderer-inject.js'='576C52AF236D251E815C3398A8A8DA419287E1281EBF2E05718DDD9FADB248CC'
 'dream-skin.css'='6CD518F4F4A2A17CCB7F4BFCF03ECF73FB3F74E9D8F3C9788751ABA06F46C828'
}
# Isolate file lifecycle tests from bundled upstream assets. Only untouched
# fixture bytes receive a trusted upstream hash; all other bytes are untrusted.
function Get-FileHash {param($LiteralPath)
 $mockName=[IO.Path]::GetFileName($LiteralPath).Replace('.rise-titlebar-original','')
 @{Hash=$(if([IO.File]::ReadAllText($LiteralPath) -ceq $script:fixtureOriginal){$script:fixtureHashes[$mockName]}else{'untrusted'})}
}
function Assert-DreamSkinNoReparseComponents {param($Path)}
foreach($name in $fixtureHashes.Keys){[IO.File]::WriteAllText((Join-Path $assets $name),$fixtureOriginal)}
Set-RiseTitlebarCompatibility -StateRoot $root
Set-RiseTitlebarCompatibility -StateRoot $root
foreach($name in $fixtureHashes.Keys){
 $text=[IO.File]::ReadAllText((Join-Path $assets $name))
 if(-not $text.Contains('[data-app-shell-header-edge-scroll], [data-app-shell-titlebar]')){throw 'Old/new selectors not preserved'}
 if(([regex]::Matches($text,'\[data-app-shell-titlebar\]')).Count -ne 1){throw 'Repeated patch is not idempotent'}
}
Set-RiseTitlebarCompatibility -StateRoot $root -Remove
foreach($name in $fixtureHashes.Keys){if([IO.File]::ReadAllText((Join-Path $assets $name)) -cne $fixtureOriginal){throw 'Rollback changed original bytes'}}
$path=Join-Path $assets 'renderer-inject.js'
[IO.File]::WriteAllText($path,'user modification')
$rejected=$false
try{Set-RiseTitlebarCompatibility -StateRoot $root}catch{$rejected=$true}
if(-not $rejected){throw 'External modification accepted'}
if([IO.File]::ReadAllText((Join-Path $assets 'selectors.json')) -cne $fixtureOriginal){throw 'Preflight failure made partial writes'}
'PASS: titlebar aliases, idempotence, rollback, external modification and preflight atomicity'
