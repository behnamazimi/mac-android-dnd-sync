#!/usr/bin/env bash
set -euo pipefail

# Writes or verifies apps/macos/FocusSync/ForwarderSecrets.local.swift so a
# Release archive can call POST /v1/pairs. The gitignored file is empty in
# CI (Xcode copies the example), and the QR step then only says "Couldn't
# start pairing. Check the internet." Never prints secret values.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file="$root/apps/macos/FocusSync/ForwarderSecrets.local.swift"
example="$file.example"

write_from_env() {
  local url="${FORWARDER_BASE_URL:-}"
  local key="${FORWARDER_APP_KEY:-}"
  if [[ -z "$url" ]]; then
    url="${FUNCTION_URL:-}"
  fi
  if [[ -z "$url" || -z "$key" ]]; then
    printf 'CI archive needs FORWARDER_APP_KEY (and FORWARDER_BASE_URL if it is not %s).\n' \
      "${FUNCTION_URL:-the function URL}" >&2
    exit 1
  fi
  python3 - "$file" "$url" "$key" <<'PY'
import sys
from pathlib import Path

path, url, key = sys.argv[1], sys.argv[2], sys.argv[3]


def swift_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


Path(path).write_text(
    "enum ForwarderLocalSecrets {\n"
    '    static let pairId = ""\n'
    '    static let pairSecret = ""\n'
    f'    static let baseURL = "{swift_string(url)}"\n'
    f'    static let appKey = "{swift_string(key)}"\n'
    "}\n",
    encoding="utf-8",
)
PY
}

verify() {
  python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print(
        "ForwarderSecrets.local.swift is missing. Fill it in locally, or in CI "
        "set FORWARDER_APP_KEY so the Release QR step can create a pair.",
        file=sys.stderr,
    )
    sys.exit(1)

text = path.read_text(encoding="utf-8")


def field(name: str) -> str:
    match = re.search(rf'static let {name} = "([^"]*)"', text)
    return match.group(1) if match else ""


if not field("baseURL") or not field("appKey"):
    print(
        "ForwarderSecrets.local.swift needs a non-empty baseURL and appKey. "
        "Empty values still compile, but the shipped QR step cannot start "
        "pairing. Set them locally, or in CI set FORWARDER_APP_KEY.",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

if [[ "${CI:-}" == "true" ]]; then
  write_from_env
elif [[ -n "${FORWARDER_APP_KEY:-}" ]]; then
  write_from_env
elif [[ ! -f "$file" ]]; then
  cp "$example" "$file"
fi

verify
printf 'ForwarderSecrets.local.swift has baseURL and appKey (values not printed).\n'
