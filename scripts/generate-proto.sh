#!/usr/bin/env bash
set -euo pipefail

# Remote buf plugins (buf.gen.yaml) hit the BSR on every `buf generate`.
# Xcode's "Generate Proto" phase and Gradle's generateProto both call this
# script on every build. Reuse existing stubs unless FORCE_PROTO=1, otherwise
# a few IDE rebuilds exhaust the BSR rate limit and fail the build.
# `make proto` sets FORCE_PROTO=1.

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
if ! command -v buf >/dev/null 2>&1; then
  echo "buf is required on PATH. Install it from https://buf.build/docs/installation" >&2
  exit 1
fi

mkdir -p apps/macos/Generated apps/android/generated forwarder/generated

out_files=(
  apps/macos/Generated/dndsync_v1_dnd_state.pb.swift
  apps/android/generated/com/dndsync/proto/v1/DndState.java
  forwarder/generated/dndsync/v1/dnd_state_pb.ts
)
stubs_present=1
for f in "${out_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    stubs_present=0
    break
  fi
done

(cd proto && buf lint)

if [[ "$stubs_present" -eq 1 && "${FORCE_PROTO:-0}" != "1" ]]; then
  echo "protobuf stubs already present; skipping buf generate (FORCE_PROTO=1 to regenerate)"
  exit 0
fi

if (cd proto && buf generate); then
  exit 0
fi

if [[ "$stubs_present" -eq 1 ]]; then
  echo "buf generate failed (often a BSR rate limit); reusing existing stubs" >&2
  exit 0
fi

exit 1
