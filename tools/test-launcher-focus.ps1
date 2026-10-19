# Run in Windows PowerShell STA after tools/build.ps1.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$payload=Join-Path $root 'build\payload'
foreach($file in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.Wpf.dll','RiseOnAir.exe')){[void][Reflection.Assembly]::LoadFrom((Join-Path $payload $file))}
$flags=[Reflection.BindingFlags]'Instance,NonPublic'
$static=[Reflection.BindingFlags]'Static,NonPublic'
[RiseOnAir.Program]::Preview=$true
$window=New-Object RiseOnAir.WebLaunchWindow($false)
try {
 if(!$window.Topmost){throw 'Fixture did not start with an intro window.'}
 [Windows.Window].GetMethod('OnDeactivated',$flags).Invoke($window,@([EventArgs]::Empty))|Out-Null
 if($window.Topmost){throw 'Switching to another app leaves an always-on-top blocker.'}
 $window.Topmost=$true
 [RiseOnAir.Program]::Preview=$false
 [RiseOnAir.Program]::ExistingSession=$false
 [RiseOnAir.Program]::ResumeFailed=$true
 [RiseOnAir.Program].GetField('resumeAttempted',$static).SetValue($null,$true)
 [RiseOnAir.Program].GetField('sessionWindow',$static).SetValue($null,[IntPtr]::Zero)
 $window.GetType().GetMethod('Finish',$flags).Invoke($window,@('media-ended'))|Out-Null
 if(-not [RiseOnAir.Program]::IntroFinished.WaitOne(0)){throw 'Intro completion did not release the native handoff gate.'}
 if($window.Topmost -or !$window.GetType().GetField('waiting',$flags).GetValue($window)){throw 'Failure/wait screen must remain a regular, non-topmost window.'}
 $window.GetType().GetMethod('Finish',$flags).Invoke($window,@('skip'))|Out-Null
 if(!$window.GetType().GetField('closing',$flags).GetValue($window)){throw 'Esc cannot close the waiting screen.'}
 'PASS deactivation releases topmost / failed startup cannot stay topmost / Esc closes waiting'
}finally{[RiseOnAir.Program]::Preview=$true;$window.Close()}
