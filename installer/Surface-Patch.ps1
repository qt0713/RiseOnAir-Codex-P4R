# An exact-version, reversible adapter. Never modifies the official Codex app.
function Set-RiseSurfaceAdapter {
 param([string]$StateRoot,[string]$InstallRoot,[switch]$Remove)
 . (Join-Path $StateRoot 'engine\scripts\common-windows.ps1')
 . (Join-Path $StateRoot 'engine\scripts\theme-windows.ps1')
 $lock=Enter-DreamSkinOperationLock -TimeoutMilliseconds 10000
 try {
  $injector=Join-Path $StateRoot 'engine\scripts\injector.mjs'
  $backup=$injector+'.rise-original'
  $extension=Join-Path $StateRoot 'engine\assets\rise-surfaces.css'
  foreach($path in @($injector,$backup,$extension)){Assert-DreamSkinNoReparseComponents -Path $path}
  $expected='962041DA9DE23A9E29DD38568E8C54EA3B200DCE37FF3A450CB09B8152583C90'
  $current=[IO.File]::ReadAllText($injector)
  $marker='/* RiseOnAir surface adapter v1 */'
  if($current.Contains($marker)){
   if(-not(Test-Path -LiteralPath $backup) -or (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $expected){throw 'Rise adapter backup is not the expected upstream version.'}
   $original=[IO.File]::ReadAllText($backup)
  } else {
   if((Get-FileHash -LiteralPath $injector -Algorithm SHA256).Hash -ne $expected){throw 'Unsupported or modified Dream Skin injector; existing theme preserved.'}
   $original=$current
  }
  $anchor='const combinedCss = loadedTheme.safeCssRuntime'
  $replacement=$marker+"`n"+'  const riseSurfaceCss = loadedTheme.theme.id === "p4r-rise-on-air" ? await fs.readFile(path.join(root, "assets", "rise-surfaces.css"), "utf8") : "";'+"`n"+'  const combinedCss = (loadedTheme.safeCssRuntime'
  $patched=$original.Replace($anchor,$replacement).Replace(': css;',': css) + "\n" + riseSurfaceCss;')
  if($current.Contains($marker) -and $current -cne $patched){throw 'Adapter was modified externally; refusing to overwrite it.'}
  if($Remove){
   if($current.Contains($marker)){[IO.File]::Copy($backup,$injector,$true)}
   if(Test-Path -LiteralPath $extension){Remove-Item -LiteralPath $extension -Force}
   return
  }
  if(-not $original.Contains($anchor)){throw 'Upstream adapter anchor not found.'}
  if(-not(Test-Path -LiteralPath $backup)){[IO.File]::Copy($injector,$backup,$false)}
  [IO.File]::Copy((Join-Path $InstallRoot 'runtime\rise-surfaces.css'),$extension,$true)
  if($current -cne $patched){[IO.File]::WriteAllText($injector,$patched,(New-Object Text.UTF8Encoding($false)))}
 } finally {Exit-DreamSkinOperationLock -Mutex $lock}
}
