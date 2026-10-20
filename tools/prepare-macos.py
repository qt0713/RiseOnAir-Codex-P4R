"""Stage the reviewed Mac app resources. Standard library only; no native build here."""
import argparse, hashlib, io, json, os, pathlib, shutil, urllib.request, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMMIT = "6fc42df48a6a5365011f55cc349e20c038e56d1d"
EXPECTED = {
    "scripts/injector.mjs": "e0fe79b75072a3bb534497f21c72c7c892a84828dd7784316ef0856fb8c41dbb",
    "scripts/common-macos.sh": "e222945a9f99d147da91e7079912b4635859b9f9a8c75f2fc3605df180620104",
    "assets/theme-preferences.mjs": "ca6ecbd2337e9cc471bfd1c62b7b84c975670a5a5c6adcb4214a4dda52f2c326",
}

def prepare(upstream=None):
    stage = ROOT / "build/macos"
    if stage.is_symlink() or stage.resolve().parent != (ROOT / "build").resolve():
        raise RuntimeError("Unsafe build directory")
    if stage.exists():
        shutil.rmtree(stage)
    resources = stage / "Rise On Air.app/Contents/Resources"
    resources.mkdir(parents=True)
    engine = resources / "engine"
    files = {}
    if upstream:
        source = pathlib.Path(upstream)
        for folder in ("scripts", "assets"):
            for file in (source / folder).iterdir():
                if file.suffix in (".sh", ".js", ".mjs", ".css", ".json"):
                    files[f"{folder}/{file.name}"] = file.read_bytes().replace(b"\r\n", b"\n")
        files["LICENSE"] = (source / "LICENSE").read_bytes()
        files["VERSION"] = (source / "VERSION").read_bytes().replace(b"\r\n", b"\n")
    else:
        url = f"https://codeload.github.com/Fei-Away/Codex-Dream-Skin/zip/{COMMIT}"
        with urllib.request.urlopen(url, timeout=90) as response:
            archive = zipfile.ZipFile(io.BytesIO(response.read()))
        prefix = f"Codex-Dream-Skin-{COMMIT}/macos/"
        for entry in archive.infolist():
            if not entry.filename.startswith(prefix) or entry.is_dir():
                continue
            name = entry.filename[len(prefix):]
            parts = pathlib.PurePosixPath(name).parts
            if name in ("LICENSE", "VERSION") or (len(parts) == 2 and parts[0] in ("scripts", "assets") and pathlib.PurePosixPath(name).suffix in (".sh", ".js", ".mjs", ".css", ".json")):
                files[name] = archive.read(entry).replace(b"\r\n", b"\n")
    for name, expected in EXPECTED.items():
        if hashlib.sha256(files[name]).hexdigest() != expected:
            raise RuntimeError(f"Unexpected upstream source: {name}")
    common = files["scripts/common-macos.sh"].decode()
    common = common.replace('INSTALL_ROOT="$HOME/.codex/codex-dream-skin-studio"', 'INSTALL_ROOT="$HOME/Library/Application Support/RiseOnAir/engine"')
    common = common.replace('STATE_ROOT="$HOME/Library/Application Support/CodexDreamSkinStudio"', 'STATE_ROOT="$HOME/Library/Application Support/RiseOnAir/DreamSkin"')
    common = common.replace("com.openai.codex-dream-skin-studio", "io.github.qt0713.riseonair.dreamskin")
    files["scripts/common-macos.sh"] = common.encode()
    injector = files["scripts/injector.mjs"].decode()
    anchor = 'const combinedCss = safeCssRuntime ? `${css}\\n${safeCssRuntime}\\n` : css;'
    if injector.count(anchor) != 1:
        raise RuntimeError("Mac injector adapter anchor changed")
    injector = injector.replace(anchor, 'const riseSurfaceCss = theme.id === "p4r-rise-on-air" ? await fs.readFile(path.join(root, "assets", "rise-surfaces.css"), "utf8") : "";\n  const combinedCss = (safeCssRuntime ? `${css}\\n${safeCssRuntime}\\n` : css) + "\\n" + riseSurfaceCss;')
    verify_anchor = 'export async function verifySession(session, expectedThemeId = null, expectedRevision = null) {'
    if injector.count(verify_anchor) != 1:
        raise RuntimeError("Mac first-paint adapter anchor changed")
    injector = injector.replace(verify_anchor, verify_anchor + '\n  if (process.env.RISE_FIRST_PAINT === "1") return (await import("./rise-first-paint.mjs")).verifyFirstPaint(session, expectedThemeId, expectedRevision, SKIN_VERSION);')
    files["scripts/rise-first-paint.mjs"] = (ROOT / "src/runtime/first-paint.mjs").read_bytes()
    files["scripts/injector.mjs"] = injector.encode()
    verifier = files["scripts/verify-dream-skin-macos.sh"].decode()
    if verifier.count('--timeout-ms 30000') != 1:
        raise RuntimeError("Mac verification timeout anchor changed")
    files["scripts/verify-dream-skin-macos.sh"] = verifier.replace(
        '--timeout-ms 30000', '--timeout-ms "${RISE_VERIFY_TIMEOUT_MS:-30000}"').encode()
    preferences = files["assets/theme-preferences.mjs"].decode().replace('"CodexDreamSkinStudio"', '"RiseOnAir", "DreamSkin"')
    files["assets/theme-preferences.mjs"] = preferences.encode()
    for name, content in files.items():
        target = engine / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        if target.suffix == ".sh": target.chmod(0o755)
    (engine / "RISE-OWNED").write_text("RiseOnAir macOS managed engine\n", encoding="utf-8")
    shutil.copy2(ROOT / "src/runtime/rise-surfaces.css", engine / "assets/rise-surfaces.css")
    shutil.copytree(ROOT / "src/theme", resources / "theme")
    # The engine's default payload is also the same owned Rise theme, never an unrelated preset image.
    for file in (ROOT / "src/theme").iterdir(): shutil.copy2(file, engine / "assets" / file.name)
    shutil.copytree(ROOT / "src/animation", resources / "animation")
    animation = resources / "animation"
    composition = (animation / "composition.js").read_text(encoding="utf-8")
    composition = composition.replace("const params=new URLSearchParams(location.search);", "const params=new URLSearchParams(location.search);params.set('responsive','1');")
    composition = composition.replace("function fit(){", "function fit(){const innerWidth=root.parentElement.clientWidth,innerHeight=root.parentElement.clientHeight;")
    (animation / "composition.js").write_text(composition, encoding="utf-8", newline="\n")
    original = (animation / "index.html").read_text(encoding="utf-8")
    body = original.split("<body>", 1)[1].split("</body>", 1)[0]
    html = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="composition.css"><style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#242124;color:#fff9ec;font:14px system-ui}#host{position:absolute;inset:48px 0 0;overflow:hidden}.bar{position:absolute;inset:0 0 auto;height:48px;display:flex;align-items:center;gap:8px;padding:0 12px}.bar span{flex:1;min-width:0}button{border:0;border-radius:7px;background:#ffffff16;color:#fff9ec;min-height:36px;padding:6px 12px;font:inherit}button:focus-visible{outline:2px solid #ffd83d}#wait{position:absolute;inset:auto 16px 24px;padding:18px;background:#242124ee;border-radius:12px;text-align:center}#wait[hidden]{display:none}
</style></head><body><div id="host">''' + body + '''</div><div class="bar"><span>RISE ON AIR</span><button id="replay" hidden>重播</button><button id="mute">静音</button><button id="skip">跳过 Esc</button></div><div id="wait" hidden></div><script src="startup-macos.js"></script></body></html>'''
    (animation / "startup-macos.html").write_text(html, encoding="utf-8", newline="\n")
    shutil.copy2(ROOT / "macos/startup.js", animation / "startup-macos.js")
    for name in ("rise-control.sh", "VERSION"):
        target = resources / name
        target.write_text((ROOT / "macos" / name).read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
    (resources / "rise-control.sh").chmod(0o755)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"): shutil.copy2(ROOT / name, resources / name)
    shutil.copytree(ROOT / "licenses", resources / "licenses")
    (resources.parent / "Info.plist").write_bytes((ROOT / "macos/Info.plist").read_bytes())
    manifest = {"product":"RiseOnAir", "version":(ROOT / "macos/VERSION").read_text().strip(), "upstreamCommit":COMMIT,
                "files":{str(p.relative_to(resources)).replace(os.sep,"/"):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(resources.rglob("*")) if p.is_file()}}
    (resources / "resource-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(resources.parent.parent)
    return resources.parent.parent

if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--upstream")
    prepare(parser.parse_args().upstream)
