#!/usr/bin/env bash
set -euo pipefail

# Cut a dogfood release: sync every product version, open a release branch,
# commit, tag vX.Y.Z, and push. Pushing the tag is what starts
# .github/workflows/release.yml.
#
# Usage:
#   ./scripts/release.sh 0.1.0
#   ./scripts/release.sh 0.1.0 --dry-run
#   ./scripts/release.sh 0.1.0 --no-push
#   ./scripts/release.sh --check

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v python3 >/dev/null 2>&1; then
	printf 'python3 is required on PATH.\n' >&2
	exit 1
fi

VERSION=""
DRY_RUN=0
NO_PUSH=0
CHECK_ONLY=0

usage() {
	cat <<'EOF'
Usage:  ./scripts/release.sh <version> [flags]
        ./scripts/release.sh --check

Sync the Mac app, Android app, and Node package versions, then open a
release/vX.Y.Z branch, commit, tag, and push. The tag push starts
.github/workflows/release.yml.

  --dry-run      Print the plan. Do not write files or run git.
  --no-push      Commit and tag locally. Do not push.
  --check        Verify every version file already matches. No writes.

Version is X.Y.Z (for example 0.1.0). Equivalent make target:
  make release VERSION=0.1.0
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=1; shift ;;
		--no-push) NO_PUSH=1; shift ;;
		--check) CHECK_ONLY=1; shift ;;
		-h|--help) usage; exit 0 ;;
		-*)
			printf 'Unknown flag: %s\n' "$1" >&2
			usage >&2
			exit 1
			;;
		*)
			if [[ -n "$VERSION" ]]; then
				printf 'Unexpected extra argument: %s\n' "$1" >&2
				exit 1
			fi
			VERSION="$1"
			shift
			;;
	esac
done

if [[ "$CHECK_ONLY" -eq 0 && -z "$VERSION" ]]; then
	usage >&2
	exit 1
fi

if [[ -n "$VERSION" && ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf 'Version must be X.Y.Z (got %s)\n' "$VERSION" >&2
	exit 1
fi

cmp_semver() {
	python3 -c 'import sys
a=tuple(int(x) for x in sys.argv[1].split("."))
b=tuple(int(x) for x in sys.argv[2].split("."))
sys.exit(0 if a<b else 1 if a>b else 2)' "$1" "$2"
}

verify_synced() {
	local expected="$1"
	python3 - "$root" "$expected" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
expected = sys.argv[2]
errors = []

def fail(msg):
    errors.append(msg)

version_file = root / "VERSION"
if not version_file.is_file():
    fail("VERSION is missing")
elif version_file.read_text().strip() != expected:
    fail(f"VERSION is {version_file.read_text().strip()!r}, expected {expected}")

pbx = (root / "apps/macos/DNDSync.xcodeproj/project.pbxproj").read_text()
app_versions = []
for block in pbx.split("isa = XCBuildConfiguration"):
    if "PRODUCT_BUNDLE_IDENTIFIER = com.dndsync.macos;" not in block:
        continue
    if "macosTests" in block:
        continue
    m = re.search(r"MARKETING_VERSION = ([^;]+);", block)
    if m:
        app_versions.append(m.group(1).strip())
unique = sorted(set(app_versions))
if unique != [expected]:
    fail(f"Mac app MARKETING_VERSION values are {unique}, expected {expected}")

gradle = (root / "apps/android/app/build.gradle.kts").read_text()
name = re.search(r'versionName = "([^"]+)"', gradle)
if not name or name.group(1) != expected:
    fail(f"Android versionName is {name.group(1) if name else 'missing'}, expected {expected}")

pkgs = [
    "forwarder/package.json",
    "scripts/fcm-send/package.json",
    "scripts/apns-send/package.json",
]
for rel in pkgs:
    path = root / rel
    data = json.loads(path.read_text())
    got = data.get("version")
    if got != expected:
        fail(f"{rel} version is {got!r}, expected {expected}")

locks = [
    "forwarder/package-lock.json",
    "scripts/fcm-send/package-lock.json",
]
for rel in locks:
    path = root / rel
    data = json.loads(path.read_text())
    got = data.get("packages", {}).get("", {}).get("version")
    if got != expected:
        fail(f"{rel} packages[''].version is {got!r}, expected {expected}")

if errors:
    print("Version files are out of sync:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)
print(f"All version files match {expected}")
PY
}

write_versions() {
	local version="$1"
	local new_build="$2"
	local new_code="$3"
	python3 - "$root" "$version" "$new_build" "$new_code" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
version = sys.argv[2]
new_build = sys.argv[3]
new_code = sys.argv[4]

pending = []

pending.append((root / "VERSION", version + "\n"))

pbx_path = root / "apps/macos/DNDSync.xcodeproj/project.pbxproj"
pbx = pbx_path.read_text()
pbx, n_m = re.subn(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", pbx)
pbx, n_b = re.subn(r"CURRENT_PROJECT_VERSION = [0-9]+;", f"CURRENT_PROJECT_VERSION = {new_build};", pbx)
if n_m < 2 or n_b < 2:
    sys.exit(f"pbxproj replacements too few (MARKETING_VERSION={n_m}, CURRENT_PROJECT_VERSION={n_b})")
pending.append((pbx_path, pbx))

gradle_path = root / "apps/android/app/build.gradle.kts"
gradle = gradle_path.read_text()
gradle, n_name = re.subn(r'versionName = "[^"]+"', f'versionName = "{version}"', gradle, count=1)
gradle, n_code = re.subn(r"versionCode = [0-9]+", f"versionCode = {new_code}", gradle, count=1)
if n_name != 1 or n_code != 1:
    sys.exit("Android versionName/versionCode replacement failed")
pending.append((gradle_path, gradle))

def set_pkg(path: Path) -> str:
    text = path.read_text()
    pattern = re.compile(
        r'("name": "[^"]+",\n)(?:  "version": "[^"]+",\n)?'
    )
    new, n = pattern.subn(rf'\1  "version": "{version}",\n', text, count=1)
    if n != 1:
        sys.exit(f"failed to set package.json version in {path}")
    data = json.loads(new)
    if data.get("version") != version:
        sys.exit(f"package.json version write did not stick in {path}")
    return new

def set_lock(path: Path) -> str:
    text = path.read_text()
    pattern = re.compile(
        r'("packages": \{\n    "": \{\n      "name": "[^"]+",\n)'
        r'(?:      "version": "[^"]+",\n)?'
    )
    new, n = pattern.subn(rf'\1      "version": "{version}",\n', text, count=1)
    if n != 1:
        sys.exit(f"failed to set lockfile root version in {path}")
    data = json.loads(new)
    got = data.get("packages", {}).get("", {}).get("version")
    if got != version:
        sys.exit(f"lockfile version write did not stick in {path}")
    return new

for rel in (
    "forwarder/package.json",
    "scripts/fcm-send/package.json",
    "scripts/apns-send/package.json",
):
    path = root / rel
    pending.append((path, set_pkg(path)))

for rel in (
    "forwarder/package-lock.json",
    "scripts/fcm-send/package-lock.json",
):
    path = root / rel
    pending.append((path, set_lock(path)))

for path, contents in pending:
    path.write_text(contents)
PY
}

if [[ "$CHECK_ONLY" -eq 1 ]]; then
	if [[ -z "$VERSION" ]]; then
		if [[ ! -f VERSION ]]; then
			printf 'VERSION is missing. Run make release VERSION=X.Y.Z first.\n' >&2
			exit 1
		fi
		VERSION="$(tr -d '[:space:]' < VERSION)"
	fi
	verify_synced "$VERSION"
	exit 0
fi

read -r current_ver current_build current_code <<<"$(python3 - "$root" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
pbx = (root / "apps/macos/DNDSync.xcodeproj/project.pbxproj").read_text()
gradle = (root / "apps/android/app/build.gradle.kts").read_text()
app_versions = []
app_builds = []
for block in pbx.split("isa = XCBuildConfiguration"):
    if "PRODUCT_BUNDLE_IDENTIFIER = com.dndsync.macos;" not in block:
        continue
    if "macosTests" in block:
        continue
    m = re.search(r"MARKETING_VERSION = ([^;]+);", block)
    b = re.search(r"CURRENT_PROJECT_VERSION = ([0-9]+);", block)
    if m:
        app_versions.append(m.group(1).strip())
    if b:
        app_builds.append(int(b.group(1)))
name = re.search(r'versionName = "([^"]+)"', gradle)
code = re.search(r"versionCode = ([0-9]+)", gradle)
unique = sorted(set(app_versions))
if len(unique) != 1:
    sys.exit(f"Mac app MARKETING_VERSION is not consistent: {unique}")
if not name or name.group(1) != unique[0]:
    sys.exit(
        f"Mac MARKETING_VERSION ({unique[0]}) != Android versionName ({name.group(1) if name else 'missing'})"
    )
print(unique[0], max(app_builds or [0]), int(code.group(1)))
PY
)"

set +e
cmp_semver "$VERSION" "$current_ver"
cmp=$?
set -e
# 0 = VERSION < current (downgrade), 1 = upgrade, 2 = same marketing version
if [[ "$cmp" -eq 0 ]]; then
	printf 'Refusing to downgrade from %s to %s\n' "$current_ver" "$VERSION" >&2
	exit 1
fi

new_build=$((current_build + 1))
new_code=$((current_code + 1))
tag="v${VERSION}"
branch="release/${tag}"

CHANGED_FILES=(
	VERSION
	apps/macos/DNDSync.xcodeproj/project.pbxproj
	apps/android/app/build.gradle.kts
	forwarder/package.json
	forwarder/package-lock.json
	scripts/fcm-send/package.json
	scripts/fcm-send/package-lock.json
	scripts/apns-send/package.json
)

printf 'Release %s\n' "$tag"
printf '  Mac marketing %s → %s (build %s → %s)\n' "$current_ver" "$VERSION" "$current_build" "$new_build"
printf '  Android versionName %s → %s (versionCode %s → %s)\n' "$current_ver" "$VERSION" "$current_code" "$new_code"
printf '  Node packages (forwarder, fcm-send, apns-send) → %s\n' "$VERSION"
printf '  Branch %s, tag %s\n' "$branch" "$tag"
if [[ "$NO_PUSH" -eq 1 ]]; then
	printf '  Push: no\n'
else
	printf '  Push: origin %s and %s\n' "$branch" "$tag"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
	printf '\nDry run. No files written.\n'
	exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	printf 'Not a git repository.\n' >&2
	exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
	printf 'Working tree is not clean. Commit or stash first.\n' >&2
	git status --short >&2
	exit 1
fi

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
	printf 'Local tag %s already exists.\n' "$tag" >&2
	exit 1
fi

if git show-ref --verify --quiet "refs/heads/${branch}"; then
	printf 'Local branch %s already exists.\n' "$branch" >&2
	exit 1
fi

git fetch origin

if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
	printf 'Origin already has tag %s.\n' "$tag" >&2
	exit 1
fi

if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
	printf 'Origin already has branch %s.\n' "$branch" >&2
	exit 1
fi

git checkout main
if git rev-parse --verify origin/main >/dev/null 2>&1; then
	git merge --ff-only origin/main
fi

git checkout -b "$branch"
write_versions "$VERSION" "$new_build" "$new_code"
verify_synced "$VERSION"

git add -- "${CHANGED_FILES[@]}"
if git diff --cached --quiet; then
	printf 'Version files produced no diff. Nothing to commit.\n' >&2
	exit 1
fi

git commit -m "$(cat <<EOF
Release ${tag}

Keep Mac, Android, and package versions on ${VERSION} for the GitHub Release.
EOF
)"

git tag "$tag"

if [[ "$NO_PUSH" -eq 1 ]]; then
	printf '\nCreated %s and tag %s locally. Push when ready:\n' "$branch" "$tag"
	printf '  git push -u origin %s && git push origin %s\n' "$branch" "$tag"
	exit 0
fi

git push -u origin "$branch"
git push origin "$tag"

if command -v gh >/dev/null 2>&1; then
	if gh pr view "$branch" >/dev/null 2>&1; then
		printf 'PR for %s already exists.\n' "$branch"
	else
		if ! gh pr create --base main --head "$branch" --title "Release ${tag}" --body "$(cat <<EOF
## Summary
- Sync Mac, Android, and Node package versions to ${VERSION}.
- Tag ${tag} to start the dogfood GitHub Release.

## Test plan
- [ ] Approve the \`release\` environment on the Actions run for ${tag}.
- [ ] Confirm the GitHub Release has the notarized \`.dmg\` and signed \`.apk\`.
EOF
)"; then
			printf 'Could not open a PR for %s; open one into main by hand.\n' "$branch" >&2
		fi
	fi
else
	printf 'gh not on PATH; open a PR for %s into main by hand.\n' "$branch"
fi

printf '\nTag %s pushed. Approve the release environment on the Actions run.\n' "$tag"
printf 'The GitHub Release is created only after that approval and both build jobs succeed.\n'
