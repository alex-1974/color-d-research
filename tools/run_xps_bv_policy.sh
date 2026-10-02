#!/usr/bin/env bash
set -euo pipefail

# Isolated, pinned consumer replay. Does not change an existing checkout,
# install compilers, or change power/SMT/turbo settings.
CVD_POLICY_REV=e948f48b71bea374702d79ae8bf9a4aba0010e56
CVD_POLICY_ROOT=$(mktemp -d /tmp/color-cvd-policy.XXXXXX)
CVD_POLICY_NOTES="XPS integrated BV policy; user notes: ${1:-not supplied}"
if command -v powerprofilesctl >/dev/null 2>&1; then
    CVD_POLICY_PROFILE=$(powerprofilesctl get 2>/dev/null || true)
    CVD_POLICY_NOTES+="; observed power profile: ${CVD_POLICY_PROFILE:-unavailable}"
fi
git clone --quiet --no-checkout https://github.com/alex-1974/color-d-research.git "$CVD_POLICY_ROOT/repo"
git -C "$CVD_POLICY_ROOT/repo" checkout --quiet --detach "$CVD_POLICY_REV"
python3 "$CVD_POLICY_ROOT/repo/experiments/r7_4_5_cvd_performance/replay.py" \
    --revision "$CVD_POLICY_REV" \
    --variants default bv_split bv_compiler \
    --sizes 1024 8191 65536 --blocks 3 \
    --notes "$CVD_POLICY_NOTES"
