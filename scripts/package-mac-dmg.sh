#!/usr/bin/env bash
set -euo pipefail

# Packages a .app into a compact Applications-drop .dmg (app on the left,
# Applications on the right, Finder window sized to that layout). Uses
# dmgbuild in a throwaway venv so we do not need Finder AppleScript, which
# is flaky on GitHub Actions. Never prints secret values.

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s <DNDSync.app> <output.dmg>\n' "$(basename "$0")" >&2
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

if [[ -d "/Volumes/DND Sync" ]]; then
	printf 'Ejecting leftover /Volumes/DND Sync so this image can use that volume name.\n' >&2
	hdiutil detach "/Volumes/DND Sync" -quiet || hdiutil detach "/Volumes/DND Sync" -force
fi

venv="$(mktemp -d "${TMPDIR:-/tmp}/dndsync-dmgbuild.XXXXXX")"
cleanup() {
	rm -rf "$venv"
}
trap cleanup EXIT

python3 -m venv "$venv"
"$venv/bin/pip" install --disable-pip-version-check -q -r "$req"

rm -f "$out"
"$venv/bin/dmgbuild" -s "$settings" -D "app=$app" "DND Sync" "$out"
printf 'Built %s\n' "$out"
