#!/usr/bin/env python3
"""Usage: stamp_version.py <build_number> <git_sha>  -> writes data/build_info.json (CI only)."""
import json, sys, pathlib
n, sha = int(sys.argv[1]), sys.argv[2][:7]
pathlib.Path(__file__).resolve().parent.parent.joinpath("data/build_info.json").write_text(
    json.dumps({"build_number": n, "git_sha": sha}))
print("stamped", n, sha)
