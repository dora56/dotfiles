#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(chezmoi source-path)"
PRIVATE_DATA_FILE="${HOME}/.config/chezmoi/private.toml"
BASE_TEMPLATE="${SOURCE_DIR}/Brewfile.tmpl"
PRIVATE_TEMPLATE="${SOURCE_DIR}/Brewfile.private.tmpl"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BASE_RENDERED="${TMP_DIR}/Brewfile"
PRIVATE_RENDERED="${TMP_DIR}/Brewfile.private"
COMBINED_RENDERED="${TMP_DIR}/Brewfile.combined"

render_template() {
  local template_path="$1"
  local output_path="$2"

  if [[ -f "${PRIVATE_DATA_FILE}" ]]; then
    (cd "${SOURCE_DIR}" && chezmoi execute-template --override-data-file "${PRIVATE_DATA_FILE}" < "${template_path}") > "${output_path}"
  else
    (cd "${SOURCE_DIR}" && chezmoi execute-template < "${template_path}") > "${output_path}"
  fi
}

extract_entries() {
  local kind="$1"
  local source_file="$2"

  case "${kind}" in
    brew)
      awk '/^brew "/ { gsub(/^brew "/, "", $0); gsub(/".*/, "", $0); sub(/^.*\//, "", $0); print }' "${source_file}" | sort -u
      ;;
    cask)
      awk '/^cask "/ { gsub(/^cask "/, "", $0); gsub(/".*/, "", $0); print }' "${source_file}" | sort -u
      ;;
    tap)
      awk '/^tap "/ { gsub(/^tap "/, "", $0); gsub(/".*/, "", $0); print }' "${source_file}" | sort -u
      ;;
    service)
      awk '/restart_service:/ { gsub(/^brew "/, "", $0); gsub(/".*/, "", $0); sub(/^.*\//, "", $0); print }' "${source_file}" | sort -u
      ;;
    *)
      return 1
      ;;
  esac
}

print_diff() {
  local title="$1"
  local expected_file="$2"
  local actual_file="$3"

  printf '\n## %s\n' "${title}"
  printf 'Missing:\n'
  comm -23 "${expected_file}" "${actual_file}" | sed 's/^/  - /' || true
  printf 'Extra:\n'
  comm -13 "${expected_file}" "${actual_file}" | sed 's/^/  - /' || true
}

render_template "${BASE_TEMPLATE}" "${BASE_RENDERED}"
if [[ -f "${PRIVATE_TEMPLATE}" ]]; then
  render_template "${PRIVATE_TEMPLATE}" "${PRIVATE_RENDERED}"
else
  : > "${PRIVATE_RENDERED}"
fi

cat "${BASE_RENDERED}" "${PRIVATE_RENDERED}" > "${COMBINED_RENDERED}"

extract_entries brew "${COMBINED_RENDERED}" > "${TMP_DIR}/expected.brews"
extract_entries cask "${COMBINED_RENDERED}" > "${TMP_DIR}/expected.casks"
extract_entries tap "${COMBINED_RENDERED}" > "${TMP_DIR}/expected.taps"
extract_entries service "${COMBINED_RENDERED}" > "${TMP_DIR}/expected.services"

brew list --formula | sort -u > "${TMP_DIR}/actual.brews"
brew list --cask | sort -u > "${TMP_DIR}/actual.casks"
brew tap | sort -u > "${TMP_DIR}/actual.taps"
brew services list | awk 'NR > 1 && $2 == "started" { print $1 }' | sort -u > "${TMP_DIR}/actual.services"

printf '# Bootstrap Audit\n'
print_diff "Formulae" "${TMP_DIR}/expected.brews" "${TMP_DIR}/actual.brews"
print_diff "Casks" "${TMP_DIR}/expected.casks" "${TMP_DIR}/actual.casks"
print_diff "Taps" "${TMP_DIR}/expected.taps" "${TMP_DIR}/actual.taps"
print_diff "Started services" "${TMP_DIR}/expected.services" "${TMP_DIR}/actual.services"

printf '\n## Unmanaged dotfiles\n'
chezmoi unmanaged | sed 's/^/  - /'
