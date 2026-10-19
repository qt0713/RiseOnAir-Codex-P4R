function Restore-RiseThemeWindow {
 param([object]$Record,[object]$Codex,[object]$Identity,[int]$Port,[string]$InstallRoot,[string]$IntroEventName)
 $owners=@((Get-DreamSkinPortListeners -Port $Port).OwningProcess|Sort-Object -Unique)
 if($owners.Count -ne 1){throw 'Ambiguous theme browser owner.'}
 $node=Get-DreamSkinNodeRuntime
 $prefix=Join-Path $InstallRoot ('logs\resume-'+[Guid]::NewGuid().ToString('N'))
 # A listening browser is not necessarily a loaded main renderer on cold start.
 $rendererDeadline=[DateTime]::UtcNow.AddSeconds(15)
 do{
  try{
   Invoke-RiseProcess -File $node.Path -Arguments @((Join-Path $InstallRoot 'runtime\resume-window.mjs'),[string]$Port,$Identity.BrowserId) -LogPrefix $prefix
   $bounds=Get-Content -LiteralPath ($prefix+'.out.log') -Raw -Encoding UTF8|ConvertFrom-Json
   break
  }catch{
   if([DateTime]::UtcNow -ge $rendererDeadline){throw}
   $current=Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex
   if(!$current -or $current.BrowserId -cne $Identity.BrowserId){throw 'Theme session changed while waiting for the main renderer.'}
   Start-Sleep -Milliseconds 200
  }
 }while($true)
 if($bounds.visibility -eq 'hidden'){
  if($Codex.Version -ne '26.1013.4894.0'){throw 'This client version has not been verified for native main-window resume.'}
  if($IntroEventName){
   $event=$null
   try{$event=[Threading.EventWaitHandle]::OpenExisting($IntroEventName);if(-not $event.WaitOne(12000)){throw 'Intro handoff timed out.'}}catch [Threading.WaitHandleCannotBeOpenedException]{}finally{if($event){$event.Dispose()}}
  }
  # Use the client's real show() path, which also updates Electron visibility
  # and input state. Win32 ShowWindow alone leaves that state stale.
  Invoke-RiseProcess -File $node.Path -Arguments @((Join-Path $InstallRoot 'runtime\resume-window.mjs'),[string]$Port,$Identity.BrowserId,'show') -LogPrefix ($prefix+'-show')
  $bounds=Get-Content -LiteralPath ($prefix+'-show.out.log') -Raw -Encoding UTF8|ConvertFrom-Json
  if($bounds.visibility -ne 'visible'){throw 'The native main-window show request did not restore renderer visibility.'}
 }
 $latest=Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $Codex
 if(!$latest -or $latest.BrowserId -cne $Identity.BrowserId){throw 'Theme session changed during resume.'}
 if(-not ('RiseOnAir.ResumeWindow' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ResumeWindow.cs')}
 $window=[RiseOnAir.ResumeWindow]::Restore($owners[0],$bounds.x,$bounds.y,$bounds.width,$bounds.height,$bounds.dpr)
 $limit=[DateTime]::UtcNow.AddSeconds(3)
 while(-not [RiseOnAir.ResumeWindow]::IsWindowVisible([IntPtr]$window) -and [DateTime]::UtcNow -lt $limit){Start-Sleep -Milliseconds 50}
 if(-not [RiseOnAir.ResumeWindow]::IsWindowVisible([IntPtr]$window)){throw 'Main window did not become visible.'}
 return $window
}
