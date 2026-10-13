#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

flutter_bin="$project_dir/.fvm/flutter_sdk/bin/flutter"
if [[ ! -x "$flutter_bin" ]]; then
  flutter_bin="$(command -v flutter)"
fi

simulator_id="${1:-}"
if [[ -n "$simulator_id" ]]; then
  shift
else
  simulator_id="$(xcrun simctl list devices booted --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
booted = [device for runtime, entries in devices.items() if "iOS" in runtime
          for device in entries if device["state"] == "Booted"]
if len(booted) != 1:
    sys.exit("请启动一个 iOS 模拟器，或把模拟器 UDID 作为第一个参数传入。")
print(booted[0]["udid"])
')"
fi

# Refuse a physical device: these flags address the simulator's Metal service.
xcrun simctl list devices --json | python3 -c '
import json, sys
identifier = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
if not any(device["udid"] == identifier for runtime, entries in devices.items()
           if "iOS" in runtime for device in entries):
    sys.exit("指定设备不是 iOS 模拟器。")
' "$simulator_id"

exec "$flutter_bin" run --debug -d "$simulator_id" \
  --no-enable-impeller --enable-software-rendering "$@"
