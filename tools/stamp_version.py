#!/usr/bin/env python3
"""Usage: stamp_version.py <build_number> <git_sha>
CI only. Writes data/build_info.json and syncs Android version/code + version/name in export_presets.cfg."""
import json, re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
n, sha = int(sys.argv[1]), sys.argv[2][:7]
(root / "data/build_info.json").write_text(json.dumps({"build_number": n, "git_sha": sha}))
ver = re.search(r'GAME_VERSION := "([^"]+)"', (root / "src/core/version.gd").read_text()).group(1)
ep = root / "export_presets.cfg"
t = ep.read_text()
t = re.sub(r'^version/code=\d+', f'version/code={n}', t, flags=re.M)
t = re.sub(r'^version/name=".*"', f'version/name="{ver}"', t, flags=re.M)
ep.write_text(t)
print("stamped build", n, "sha", sha, "version", ver)
