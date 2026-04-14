#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -x "${SCRIPT_DIR}/install.sh" ]]; then
  exec "${SCRIPT_DIR}/install.sh" "$@"
fi

if command -v chezmoi >/dev/null 2>&1; then
  SOURCE_DIR="$(chezmoi source-path 2>/dev/null || true)"
  if [[ -n "${SOURCE_DIR}" && -x "${SOURCE_DIR}/install.sh" ]]; then
    exec "${SOURCE_DIR}/install.sh" "$@"
  fi
fi

printf 'install.sh was not found next to mac-install.sh or in the chezmoi source directory.\n' >&2
exit 1
