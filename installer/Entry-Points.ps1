# Only documented Shell properties and our own HKCU login value are changed.
function Import-RiseShellIdentity {
 if(-not ('RiseOnAir.ShellIdentity' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ShellIdentity.cs')}
}
function Set-RiseWindowRelaunch {
 param([string]$InstallRoot,[object]$Record,[switch]$Remove)
 Import-RiseShellIdentity
 $pkg=Get-AppxPackage -Name OpenAI.Codex|Select-Object -First 1
 if(-not $pkg -or $pkg.SignatureKind -ne 'Store'){throw 'Registered official Codex is required.'}
 $expected=Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
 foreach($p in Get-Process -Name ChatGPT -ErrorAction SilentlyContinue){
  try {
   if($p.MainWindowHandle -eq [IntPtr]::Zero -or $p.Path -ine $expected){continue}
   $hwnd=$p.MainWindowHandle.ToInt64()
   # A distinct identity avoids Shell canonicalizing the wrapper to AppsFolder.
   # Relaunch display name and command must be set together (Microsoft contract).
   $values=@{2=('"'+(Join-Path $InstallRoot 'RiseOnAir.exe')+'"');3=((Join-Path $InstallRoot 'rise-icon-v1.ico')+',0');4='Codex - Rise On Air';5='qt0713.RiseOnAir.Codex'}
   foreach($id in @(2,3,4,5)){
    $value=if($Remove){$null}else{$values[$id]}
    [RiseOnAir.ShellIdentity]::Write($null,$hwnd,$id,$value)
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
 if(-not(Test-Path -LiteralPath $run)){New-Item -Path $run|Out-Null}
 New-ItemProperty -LiteralPath $run -Name 'RiseOnAir' -Value $command -PropertyType String -Force|Out-Null
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
