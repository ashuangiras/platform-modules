#!/usr/bin/env bash
# guard-destructive-ops.sh — PreToolUse safety hook for platform-modules
# AGT-008: prompts before force-push, hard-reset, rm -rf, --no-verify, branch/tag delete.

set -euo pipefail
TOOL_INPUT="${TOOL_INPUT:-}"
DESTRUCTIVE_PATTERNS=("force" "hard" "rm -rf" "--no-verify" "branch.*-[Dd]" "tag.*-[Dd]")

for pattern in "${DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "${TOOL_INPUT}" | grep -qE "(^|[^a-zA-Z])${pattern}"; then
    echo "⚠  SAFETY HOOK: destructive pattern detected (${pattern}) — platform-modules"
    read -r -p "   Proceed? (yes/no): " answer
    [[ "${answer}" == "yes" ]] || { echo "Aborted."; exit 1; }
  fi
done
exit 0
