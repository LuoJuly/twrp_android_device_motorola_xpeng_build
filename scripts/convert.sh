#!/usr/bin/env bash
# Convert twrp.dependencies / omni.dependencies JSON into roomservice.xml.
# Uses Python JSON parsing so keys like "remote" are not confused with "repository".
set -euo pipefail

if [ -z "${1:-}" ] || [ ! -e "$1" ]; then
	echo " ** Input File : ${1:-} does not exist"
	echo " ** Please specify the correct dependencies file"
	echo " ** Usage : bash <path-to-script> <path-to-dependencies-file> [<path-to-local-manifest>]"
	exit 1
fi

DEP_FILE="$1"
if [ -n "${2:-}" ]; then
	MANIFEST_PATH="$2"
elif [ -d .repo ]; then
	mkdir -p .repo/local_manifests
	MANIFEST_PATH=".repo/local_manifests/roomservice.xml"
else
	echo " ** Manifest file to create not specified."
	echo " ** And .repo folder does not exist in $PWD"
	echo " ** Usage : bash <path-to-script> <path-to-dependencies-file> [<path-to-local-manifest>]"
	exit 1
fi

export DEP_FILE MANIFEST_PATH
python3 - <<'PY'
import json
import os
import sys

dep_file = os.environ["DEP_FILE"]
manifest_path = os.environ["MANIFEST_PATH"]

with open(dep_file, encoding="utf-8") as f:
    deps = json.load(f)
if isinstance(deps, dict):
    deps = [deps]
if not isinstance(deps, list):
    print(f" ** {dep_file} is not a JSON list/object", file=sys.stderr)
    sys.exit(1)

if os.path.isfile(manifest_path):
    with open(manifest_path, encoding="utf-8") as f:
        text = f.read()
    text = text.replace("</manifest>", "").rstrip() + "\n"
else:
    text = '<?xml version="1.0" encoding="UTF-8"?>\n<manifest>\n'

lines = [text]
for d in deps:
    if not isinstance(d, dict):
        continue
    repo = d.get("repository") or ""
    path = d.get("target_path") or ""
    if not repo or not path:
        continue
    attrs = [f'path="{path}"', f'name="{repo}"']
    remote = d.get("remote") or ""
    if remote:
        attrs.append(f'remote="{remote}"')
    revision = d.get("branch") or d.get("revision") or ""
    if revision:
        attrs.append(f'revision="{revision}"')
    lines.append("  <project " + " ".join(attrs) + " />\n")
    print(f" == roomservice: {path} <- {repo} @{revision or 'default'}")
lines.append("</manifest>\n")

os.makedirs(os.path.dirname(manifest_path) or ".", exist_ok=True)
with open(manifest_path, "w", encoding="utf-8") as f:
    f.writelines(lines)
print(f" == wrote {manifest_path}")
PY
