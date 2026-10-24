# Only documented Shell properties and our own HKCU login value are changed.
function Import-RiseShellIdentity {
 if(-not ('RiseOnAir.ShellIdentity' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ShellIdentity.cs')}
}
function Set-RiseWindowRelaunch {
 param([string]$InstallRoot,[object]$Record,[switch]$Remove,[long]$NativeWindow=0)
 # Installers and generic process enumeration cannot identify the theme surface.
 if(-not $Remove -and -not $NativeWindow){return}
 Import-RiseShellIdentity
 $pkg=Get-AppxPackage -Name OpenAI.Codex|Select-Object -First 1
 if(-not $pkg -or $pkg.SignatureKind -ne 'Store'){throw 'Registered official Codex is required.'}
 $expected=Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
 $bridge=Join-Path $InstallRoot 'RiseIconBridge.exe'
 if($Remove -and (Test-Path -LiteralPath $bridge)){Invoke-RiseProcess -File $bridge -Arguments @('--stop')}
 $targets=if($NativeWindow){Get-Process -Id ([RiseOnAir.ShellIdentity]::WindowProcess($NativeWindow)) -ErrorAction Stop}else{Get-Process -Name ChatGPT -ErrorAction SilentlyContinue}
 foreach($p in $targets){
  try {
   $hwnd=if($NativeWindow){$NativeWindow}else{$p.MainWindowHandle.ToInt64()}
   if(-not $hwnd -or $p.Path -ine $expected -or [RiseOnAir.ShellIdentity]::WindowProcess($hwnd) -ne $p.Id){continue}
   # Store updates change WindowsApps paths. Refresh only after matching this
   # real window's process to the currently registered official executable.
   if(-not $Remove){[IO.File]::WriteAllText((Join-Path $InstallRoot 'CodexExe.txt'),$expected)}
   if(-not $Remove){
    # Older installers grouped every visible official process as a Rise client.
    # Clear only our exact overrides on other instances, keeping them running.
    foreach($other in Get-Process -Name ChatGPT -ErrorAction SilentlyContinue){
     try{
      if($other.Id -eq $p.Id -or $other.Path -ine $expected -or $other.MainWindowHandle -eq [IntPtr]::Zero){continue}
      $otherWindow=$other.MainWindowHandle.ToInt64()
      if([RiseOnAir.ShellIdentity]::Read($null,$otherWindow,5) -ceq 'qt0713.RiseOnAir.Codex.Client' -and [RiseOnAir.ShellIdentity]::Read($null,$otherWindow,2) -ceq ('"'+(Join-Path $InstallRoot 'RiseOnAir.exe')+'"')){
       $defaults=@{2=('"'+$expected+'"');3=($expected+',0');4='Codex';5=($Record.codexPackageFamily+'!App')}
       foreach($id in @(2,3,4,5)){[RiseOnAir.ShellIdentity]::Write($null,$otherWindow,$id,$defaults[$id])}
      }
     }catch{Write-Warning ('Legacy window grouping could not be restored: '+$_.Exception.Message)}finally{$other.Dispose()}
    }
   }
   # Keep the native app separate from the launcher pin: otherwise Shell
   # activates its running window and never executes the animation launcher.
   # Relaunch display name and command must be set together (Microsoft contract).
   $values=@{2=('"'+(Join-Path $InstallRoot 'RiseOnAir.exe')+'"');3=((Join-Path $InstallRoot 'rise-icon-v1.ico')+',0');4='Codex - Rise On Air';5='qt0713.RiseOnAir.Codex.Client'}
   foreach($id in @(2,3,4,5)){
    $value=if($Remove){$null}else{$values[$id]}
    if([RiseOnAir.ShellIdentity]::Read($null,$hwnd,$id) -cne $value){[RiseOnAir.ShellIdentity]::Write($null,$hwnd,$id,$value)}
   }
   if(-not $Remove -and (Test-Path -LiteralPath $bridge)){
    $bound=$false
    try{
     $state=Get-Content -LiteralPath (Join-Path $InstallRoot 'icon-bridge.json') -Raw -Encoding UTF8|ConvertFrom-Json
     $keeper=Get-Process -Id $state.bridgePid -ErrorAction Stop
     $bound=$state.window -eq $hwnd -and $state.appPid -eq $p.Id -and $state.appTicks -eq $p.StartTime.ToUniversalTime().Ticks -and $keeper.Path -ieq $bridge -and $keeper.StartTime.ToUniversalTime().Ticks -eq $state.bridgeTicks
    }catch{}finally{if($keeper){$keeper.Dispose();$keeper=$null}}
    if($bound){continue}
    Invoke-RiseProcess -File $bridge -Arguments @('--stop')
    $arguments=@([string]$p.Id,[string]$p.StartTime.ToUniversalTime().Ticks,('"'+$expected+'"'),[string]$hwnd) -join ' '
    Start-Process -FilePath $bridge -ArgumentList $arguments -WindowStyle Hidden|Out-Null
   }
  } finally {$p.Dispose()}
 }
}
function Set-RiseEntryPoints {
 param([string]$InstallRoot,[object]$Record,[switch]$Remove)
 Import-RiseShellIdentity
 $exe=Join-Path $InstallRoot 'RiseOnAir.exe'
 $run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
 $command='"'+$exe+'" --login'
 $marker=Join-Path $InstallRoot 'entry-points.json'
 $backups=Join-Path $InstallRoot 'entry-point-backups'
 $saved=if(Test-Path -LiteralPath $marker){Get-Content -LiteralPath $marker -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
 if($Remove){
  $current=Get-ItemPropertyValue -LiteralPath $run -Name 'RiseOnAir' -ErrorAction SilentlyContinue
  if($current -ceq $command){Remove-ItemProperty -LiteralPath $run -Name 'RiseOnAir'}
  foreach($item in @($saved.shortcuts)){
   if($item -and (Test-Path -LiteralPath $item.path) -and (Test-Path -LiteralPath $item.backup) -and (Get-FileHash -LiteralPath $item.path).Hash -eq $item.managedHash){
    Copy-Item -LiteralPath $item.backup -Destination $item.path -Force
    $link=(New-Object -ComObject WScript.Shell).CreateShortcut($item.path)
    if($link.TargetPath -ieq $exe){
     # A legacy Rise pin must not point at the soon-to-be-uninstalled wrapper.
     $pkg=Get-AppxPackage -Name OpenAI.Codex|Select-Object -First 1
     $official=Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
     $link.TargetPath=$official;$link.Arguments='';$link.IconLocation=$official+',0';$link.Save()
     [RiseOnAir.ShellIdentity]::Write($item.path,0,5,($Record.codexPackageFamily+'!App'))
    }
   }
  }
  Set-RiseWindowRelaunch -InstallRoot $InstallRoot -Record $Record -Remove
  return
 }
 if(Test-Path -LiteralPath (Join-Path $InstallRoot 'EnableLogin.flag')){
  if(-not(Test-Path -LiteralPath $run)){New-Item -Path $run|Out-Null}
  New-ItemProperty -LiteralPath $run -Name 'RiseOnAir' -Value $command -PropertyType String -Force|Out-Null
 }else{
  $current=Get-ItemPropertyValue -LiteralPath $run -Name 'RiseOnAir' -ErrorAction SilentlyContinue
  if($current -ceq $command){Remove-ItemProperty -LiteralPath $run -Name 'RiseOnAir'}
 }
 New-Item -ItemType Directory -Path $backups -Force|Out-Null
 $pin=Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
 $w=New-Object -ComObject WScript.Shell
 $pkg=Get-AppxPackage -Name OpenAI.Codex|Select-Object -First 1
 $official=Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
 $appId=$Record.codexPackageFamily+'!App'
 $entries=New-Object System.Collections.Generic.List[object]
 foreach($item in @($saved.shortcuts)){if($item){$entries.Add($item)}}
 foreach($file in Get-ChildItem -LiteralPath $pin -Filter '*.lnk' -ErrorAction SilentlyContinue){
  $link=$w.CreateShortcut($file.FullName)
  $id=[RiseOnAir.ShellIdentity]::Read($file.FullName,0,5)
  # No fuzzy filename matching: only exact installed/registered targets or AUMID.
  if($link.TargetPath -ine $exe -and $link.TargetPath -ine $official -and $id -cne $appId -and $id -cne 'qt0713.RiseOnAir.Codex'){continue}
  $item=$entries|Where-Object{$_.path -eq $file.FullName}|Select-Object -First 1
  if(-not $item){
   $backup=Join-Path $backups ([Guid]::NewGuid().ToString('N')+'.lnk')
   Copy-Item -LiteralPath $file.FullName -Destination $backup
   $item=[pscustomobject]@{path=$file.FullName;backup=$backup;managedHash=''};$entries.Add($item)
  }
  $link.TargetPath=$exe;$link.Arguments='';$link.WorkingDirectory=$InstallRoot
  $link.IconLocation=(Join-Path $InstallRoot 'rise-icon-v1.ico')+',0';$link.Save()
  [RiseOnAir.ShellIdentity]::Write($file.FullName,0,5,'qt0713.RiseOnAir.Codex')
  $item.managedHash=(Get-FileHash -LiteralPath $file.FullName).Hash
 }
 [IO.File]::WriteAllText($marker,(@{schema=1;shortcuts=@($entries.ToArray())}|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
}
