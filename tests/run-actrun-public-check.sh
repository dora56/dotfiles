#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/actrun-bootstrap.XXXXXX")"
TMP_REPO="${TMP_ROOT}/repo"
RUN_ROOT="${TMP_ROOT}/runs"
ARTIFACT_ROOT="${TMP_ROOT}/artifacts"
CACHE_ROOT="${TMP_ROOT}/cache"
GITHUB_ACTION_CACHE_ROOT="${TMP_ROOT}/github-action-cache"
REGISTRY_ROOT="${TMP_ROOT}/registry"
KEEP_ACTRUN_TMP="${KEEP_ACTRUN_TMP:-false}"
BREW_BUNDLE_MODE="${BOOTSTRAP_BREW_BUNDLE_MODE:-check}"

cleanup() {
  if [[ -d "${TMP_REPO}" ]]; then
    git -C "${REPO_ROOT}" worktree remove --force "${TMP_REPO}" >/dev/null 2>&1 || true
  fi

  if [[ "${KEEP_ACTRUN_TMP}" == "true" ]]; then
    printf 'Kept actrun temp workspace at %s\n' "${TMP_ROOT}"
    return
  fi

  rm -rf "${TMP_ROOT}"
}

trap cleanup EXIT

mkdir -p \
  "${RUN_ROOT}" \
  "${ARTIFACT_ROOT}" \
  "${CACHE_ROOT}" \
  "${GITHUB_ACTION_CACHE_ROOT}" \
  "${REGISTRY_ROOT}"

git -C "${REPO_ROOT}" worktree add --detach "${TMP_REPO}" HEAD >/dev/null
rsync -a --delete --exclude '.git' --exclude '_build' "${REPO_ROOT}/" "${TMP_REPO}/"

git -C "${TMP_REPO}" add -A
if ! git -C "${TMP_REPO}" diff --cached --quiet; then
  git -C "${TMP_REPO}" \
    -c user.name="Codex" \
    -c user.email="codex@example.invalid" \
    commit -m "actrun temp snapshot" >/dev/null
fi

cd "${TMP_REPO}"

BOOTSTRAP_BREW_BUNDLE_MODE="${BREW_BUNDLE_MODE}" \
actrun workflow run .github/workflows/test.yml \
  --job mac-test \
  --trust \
  --local \
  --run-root "${RUN_ROOT}" \
  --artifact-root "${ARTIFACT_ROOT}" \
  --cache-root "${CACHE_ROOT}" \
  --github-action-cache-root "${GITHUB_ACTION_CACHE_ROOT}" \
  --registry-root "${REGISTRY_ROOT}" \
  "$@"
