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
  $legacyPatched=$patched
  $verifyAnchor='  const nativeWindow = await inspectTargetWindow(session, targetId);'
  $verifyHook='  if (process.env.RISE_FIRST_PAINT === "1") return (await import("./rise-first-paint.mjs")).verifyFirstPaint(session, expectedThemeId, expectedRevision, SKIN_VERSION);'
  if(-not $original.Contains($verifyAnchor)){throw 'Startup verification anchor not found.'}
  $patched=$patched.Replace($verifyAnchor,$verifyHook+"`n"+$verifyAnchor)
  if($current.Contains($marker) -and $current -cne $patched -and $current -cne $legacyPatched){throw 'Adapter was modified externally; refusing to overwrite it.'}
  $firstPaint=Join-Path $StateRoot 'engine\scripts\rise-first-paint.mjs'
  Assert-DreamSkinNoReparseComponents -Path $firstPaint
  # The startup script is separately pinned and backed up; install/manual
  # operations retain the original full preset initialization.
  $starter=Join-Path $StateRoot 'engine\scripts\start-dream-skin.ps1'
  $starterBackup=$starter+'.rise-original'
  foreach($path in @($starter,$starterBackup)){Assert-DreamSkinNoReparseComponents -Path $path}
  $starterHash='01368904D63812B208D1200E8271568E0315202713B57D710901F534FCC94902'
  $starterOriginalPath=if(Test-Path -LiteralPath $starterBackup){$starterBackup}else{$starter}
  if((Get-FileHash -LiteralPath $starterOriginalPath).Hash -ne $starterHash){throw 'Unsupported startup engine; existing files preserved.'}
  $starterOriginal=[IO.File]::ReadAllText($starterOriginalPath)
  $initAnchor='  $themePaths = Initialize-DreamSkinThemeStore -SkillRoot (Split-Path -Parent $PSScriptRoot) -StateRoot $StateRoot'
  $initReplacement=@'
  if ($env:RISE_FIRST_PAINT -eq '1' -and (Test-Path -LiteralPath (Join-Path $StateRoot 'active-theme\theme.json'))) {
    $themePaths = Get-DreamSkinThemePaths -StateRoot $StateRoot
    Invoke-DreamSkinThemeReplacementRecovery -Paths $themePaths
    $null = Read-DreamSkinTheme -ThemeDirectory $themePaths.Active
  } else {
    $themePaths = Initialize-DreamSkinThemeStore -SkillRoot (Split-Path -Parent $PSScriptRoot) -StateRoot $StateRoot
  }
'@
  if(-not $starterOriginal.Contains($initAnchor)){throw 'Startup initialization anchor not found.'}
  $starterPatched=$starterOriginal.Replace($initAnchor,$initReplacement)
  $starterCurrent=[IO.File]::ReadAllText($starter)
  if($starterCurrent -cne $starterOriginal -and $starterCurrent -cne $starterPatched){throw 'Startup adapter was modified externally.'}
  if($Remove){
   if($current.Contains($marker)){[IO.File]::Copy($backup,$injector,$true)}
   if(Test-Path -LiteralPath $starterBackup){[IO.File]::Copy($starterBackup,$starter,$true)}
   if(Test-Path -LiteralPath $firstPaint){Remove-Item -LiteralPath $firstPaint -Force}
   if(Test-Path -LiteralPath $extension){Remove-Item -LiteralPath $extension -Force}
   return
  }
  if(-not $original.Contains($anchor)){throw 'Upstream adapter anchor not found.'}
  if(-not(Test-Path -LiteralPath $backup)){[IO.File]::Copy($injector,$backup,$false)}
  if(-not(Test-Path -LiteralPath $starterBackup)){[IO.File]::Copy($starter,$starterBackup,$false)}
  [IO.File]::Copy((Join-Path $InstallRoot 'runtime\first-paint.mjs'),$firstPaint,$true)
  [IO.File]::Copy((Join-Path $InstallRoot 'runtime\rise-surfaces.css'),$extension,$true)
  if($current -cne $patched){[IO.File]::WriteAllText($injector,$patched,(New-Object Text.UTF8Encoding($false)))}
  if($starterCurrent -cne $starterPatched){[IO.File]::WriteAllText($starter,$starterPatched,(New-Object Text.UTF8Encoding($true)))}
 } finally {Exit-DreamSkinOperationLock -Mutex $lock}
}
