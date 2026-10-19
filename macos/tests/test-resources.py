import hashlib, json, pathlib, subprocess, sys, tempfile

app = pathlib.Path(sys.argv[1]).resolve()
r = app / "Contents/Resources"
manifest = json.loads((r / "resource-manifest.json").read_text())
assert manifest["product"] == "RiseOnAir"
for name, expected in manifest["files"].items():
    path = (r / name).resolve()
    assert path.is_relative_to(r) and path.is_file()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
assert (r / "RiseOnAir.icns").stat().st_size > 1000
assert (r / "theme/theme.json").is_file()
assert json.loads((r / "theme/theme.json").read_text())["id"] == "p4r-rise-on-air"
common = (r / "engine/scripts/common-macos.sh").read_text()
assert 'STATE_ROOT="$HOME/Library/Application Support/RiseOnAir/DreamSkin"' in common
assert 'EXPECTED_CODEX_TEAM_ID="2DC432GLL2"' in common
assert "require_signed_node_runtime" in common
assert not list(r.rglob("*.exe")) and not list(r.rglob("*.dll"))
assert not list(r.rglob("*arina*"))
assert "window.chrome" not in (r / "animation/startup-macos.js").read_text()
assert "<iframe" not in (r / "animation/startup-macos.html").read_text()
with tempfile.TemporaryDirectory(prefix="rise-macos-test-") as temporary:
    # macOS /var is itself a symlink. Resolve it so this test reaches the
    # genuine-app precondition instead of passing via the separate path guard.
    home = pathlib.Path(temporary).resolve()
    config = home / ".codex/config.toml"
    config.parent.mkdir()
    config.write_text('test_sentinel = "preserve-me"\n')
    before = config.read_bytes()
    import os
    env = dict(os.environ, HOME=str(home), CODEX_APP_BUNDLE=str(home / "Missing.app"))
    result = subprocess.run(["/bin/bash", str(r / "rise-control.sh"), "preflight"], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0, "A machine without a genuine Codex app must fail closed"
    assert b"Could not find the official" in result.stderr, result.stderr
    result = subprocess.run(["/bin/bash", str(r / "rise-control.sh"), "install"], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0 and b"Could not find the official" in result.stderr
    assert not (home / "Library/Application Support/RiseOnAir/engine").exists()
    assert config.read_bytes() == before
    # Exercise the real login-item writer with XML metacharacters in HOME.
    import plistlib
    login_home = home / 'login & <test>'
    login_home.mkdir()
    login_env = dict(env, HOME=str(login_home))
    control = ["/bin/bash", str(r / "rise-control.sh")]
    subprocess.run(control + ["register-login"], env=login_env, check=True, capture_output=True)
    plist = login_home / "Library/LaunchAgents/io.github.qt0713.riseonair.login.plist"
    data = plistlib.loads(plist.read_bytes())
    assert data["ProgramArguments"] == [str(app / "Contents/MacOS/RiseOnAir"), "--login"]
    assert data["RunAtLoad"] and not data["KeepAlive"]
    assert data["StandardOutPath"] == str(login_home / "Library/Application Support/RiseOnAir/login.log")
    subprocess.run(control + ["register-login"], env=login_env, check=True, capture_output=True)
    assert plistlib.loads(plist.read_bytes()) == data
    result = subprocess.run(control + ["login"], env=login_env, capture_output=True, timeout=10)
    assert result.returncode != 0 and not (login_home / "Library/Application Support/RiseOnAir/engine").exists()
    subprocess.run(control + ["remove-login"], env=login_env, check=True, capture_output=True)
    assert not plist.exists()
    support = home / "Library/Application Support/RiseOnAir"
    if support.exists():
        import shutil
        shutil.rmtree(support)
    outside = home / "outside"
    outside.mkdir()
    support.parent.mkdir(parents=True, exist_ok=True)
    support.symlink_to(outside, target_is_directory=True)
    result = subprocess.run(["/bin/bash", str(r / "rise-control.sh"), "install"], env=env, capture_output=True, timeout=30)
    assert result.returncode != 0
    assert not list(outside.iterdir())
    assert config.read_bytes() == before
print(json.dumps({"manifest":True,"isolatedState":True,"missingOfficialAppRejected":True,"configPreserved":True,"symlinkRejected":True,"loginPlistRoundTrip":True,"quietLoginNoInstall":True}))
