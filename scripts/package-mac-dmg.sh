#!/usr/bin/env bash
set -euo pipefail

# Packages a .app into a compact Applications-drop .dmg (app on the left,
# Applications on the right, Finder window sized to that layout). Uses
# dmgbuild in a throwaway venv so we do not need Finder AppleScript, which
# is flaky on GitHub Actions. Never prints secret values.
#
# Xcode exports Focus Sync.app. The image shows that same bundle on a
# volume named Focus Sync.

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s <Focus Sync.app> <output.dmg>\n' "$(basename "$0")" >&2
	exit 1
fi

app="$1"
out="$2"

if [[ ! -d "$app" ]]; then
	printf 'Not an app bundle: %s\n' "$app" >&2
	exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
	printf 'python3 is required to package the Mac .dmg.\n' >&2
	exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$root/scripts/dmg/settings.py"
req="$root/scripts/dmg/requirements.txt"

mkdir -p "$(dirname "$out")"
app="$(cd "$(dirname "$app")" && pwd)/$(basename "$app")"
out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

volume="Focus Sync"
if [[ -d "/Volumes/${volume}" ]]; then
	printf 'Ejecting leftover /Volumes/%s so this image can use that volume name.\n' "$volume" >&2
	hdiutil detach "/Volumes/${volume}" -quiet || hdiutil detach "/Volumes/${volume}" -force
fi

venv="$(mktemp -d "${TMPDIR:-/tmp}/dndsync-dmgbuild.XXXXXX")"
stage="$(mktemp -d "${TMPDIR:-/tmp}/dndsync-dmgstage.XXXXXX")"
staged="${stage}/Focus Sync.app"
cleanup() {
	rm -rf "$venv" "$stage"
}
trap cleanup EXIT

ditto "$app" "$staged"

python3 -m venv "$venv"
"$venv/bin/pip" install --disable-pip-version-check -q -r "$req"

rm -f "$out"
"$venv/bin/dmgbuild" -s "$settings" -D "app=$staged" "$volume" "$out"
printf 'Built %s\n' "$out"
