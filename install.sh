#!/usr/bin/env bash
set -euo pipefail

PHASE="auto"
ORIGINAL_HOME="${HOME}"
BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-${HOME}}"
export HOME="${BOOTSTRAP_HOME}"
REPO_ROOT="${BOOTSTRAP_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"
BREW_BUNDLE_MODE="${BOOTSTRAP_BREW_BUNDLE_MODE:-install}"
PRIVATE_DATA_FILE="${BOOTSTRAP_PRIVATE_DATA_FILE:-${HOME}/.config/chezmoi/private.toml}"
PRIVATE_EXAMPLE_FILE="${REPO_ROOT}/private.example.toml"
PUBLIC_BREWFILE="${HOME}/Brewfile"
CI_BREWFILE="${REPO_ROOT}/tests/Brewfile"
PRIVATE_BREW_TEMPLATE="${REPO_ROOT}/Brewfile.private.tmpl"
PUBLIC_DEFAULTS_SCRIPT="${HOME}/.scripts/mac/apply-public-defaults.sh"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--phase auto|public|private]

Phases:
  auto    Apply the public baseline and continue into the private overlay when
          1Password is ready.
  public  Apply only the public baseline. This is the CI-safe mode.
  private Apply only the private overlay. Assumes the public phase already ran.

Environment:
  BOOTSTRAP_HOME              Override HOME for a safe temporary bootstrap target.
  BOOTSTRAP_BREW_BUNDLE_MODE  One of: install, check.
EOF
}

log_section() {
  printf '\n-----------------------------\n'
  printf -- '- %25s -\n' "$1"
  printf '%s\n' '-----------------------------'
}

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_warn() {
  printf '[WARN] %s\n' "$1" >&2
}

log_success() {
  printf '\033[32m%s\033[0m\n' "$1"
}

is_ci() {
  [[ "$GITHUB_ACTIONS" == "true" ]]
}

log_bootstrap_context() {
  if [[ "${HOME}" != "${ORIGINAL_HOME}" ]]; then
    log_info "Using isolated bootstrap HOME at ${HOME}."
  fi

  if [[ "${BREW_BUNDLE_MODE}" == "check" ]]; then
    log_info "Homebrew bundle is running in check-only mode."
  fi
}

ensure_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  fi
}

ensure_homebrew() {
  log_section "Homebrew"
  if command -v brew >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/brew ]]; then
    ensure_brew_shellenv
    log_info "Homebrew is already available."
    return
  fi

  log_info "Installing Homebrew."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ensure_brew_shellenv
}

ensure_chezmoi() {
  log_section "chezmoi"
  if command -v chezmoi >/dev/null 2>&1; then
    log_info "chezmoi is already available."
    return
  fi

  brew install chezmoi
}

ensure_directories() {
  log_section "Directories"
  mkdir -p \
    "${HOME}/Development" \
    "${HOME}/.cache" \
    "${HOME}/.config/chezmoi" \
    "${HOME}/.zfunc"
}

seed_private_data_file() {
  if [[ -f "${PRIVATE_DATA_FILE}" ]]; then
    return
  fi

  if [[ ! -f "${PRIVATE_EXAMPLE_FILE}" ]]; then
    return
  fi

  cp "${PRIVATE_EXAMPLE_FILE}" "${PRIVATE_DATA_FILE}"
  chmod 600 "${PRIVATE_DATA_FILE}"
  log_info "Created ${PRIVATE_DATA_FILE} from private.example.toml."
}

replace_private_key() {
  local key="$1"
  local value="$2"
  local file="$3"
  local tmp

  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      print key " = \"" value "\""
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print ""
        print "[private]"
        print key " = \"" value "\""
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  chmod 600 "$file"
}

read_private_key() {
  local key="$1"
  local file="$2"

  [[ -f "$file" ]] || return 0
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/^"/, "", $0)
      gsub(/"$/, "", $0)
      print
      exit
    }
  ' "$file"
}

apply_public_dotfiles() {
  log_section "Public Dotfiles"
  chezmoi apply --source "${REPO_ROOT}"
}

apply_private_dotfiles() {
  log_section "Private Dotfiles"
  chezmoi apply --source "${REPO_ROOT}" --override-data-file "${PRIVATE_DATA_FILE}"
}

ensure_go_toolchain() {
  log_section "Go"
  if command -v go >/dev/null 2>&1; then
    log_info "Go is already available."
    return
  fi

  brew install go
}

ensure_rust_toolchain() {
  log_section "Rust"
  if command -v cargo >/dev/null 2>&1; then
    log_info "Rust toolchain is already available."
    return
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  fi
}

ensure_actrun() {
  log_section "actrun"
  if command -v actrun >/dev/null 2>&1; then
    log_info "actrun is already available."
    return
  fi

  curl -fsSL https://raw.githubusercontent.com/mizchi/actrun/main/install.sh | sh
}

run_brew_bundle() {
  local brewfile="$1"

  log_section "brew bundle"
  case "${BREW_BUNDLE_MODE}" in
    install)
      brew bundle --file "${brewfile}"
      ;;
    check)
      brew bundle check --no-upgrade --file "${brewfile}"
      ;;
    *)
      printf 'Invalid BOOTSTRAP_BREW_BUNDLE_MODE: %s\n' "${BREW_BUNDLE_MODE}" >&2
      exit 1
      ;;
  esac
}

render_private_bundle() {
  local destination="$1"

  [[ -f "${PRIVATE_BREW_TEMPLATE}" ]] || return 1

  (
    cd "${REPO_ROOT}"
    chezmoi execute-template --override-data-file "${PRIVATE_DATA_FILE}" < "${PRIVATE_BREW_TEMPLATE}"
  ) > "${destination}"

  if grep -qE '^(brew|cask|mas|vscode|go|cargo|uv) ' "${destination}"; then
    return 0
  fi

  return 1
}

choose_onepassword_account() {
  local configured_account accounts_json selected_account

  command -v op >/dev/null 2>&1 || return 1
  accounts_json="$(op account list --format json 2>/dev/null || true)"
  [[ -n "${accounts_json}" && "${accounts_json}" != "[]" ]] || return 1

  configured_account="$(read_private_key "op_account" "${PRIVATE_DATA_FILE}")"

  if [[ -n "${configured_account}" ]]; then
    selected_account="$(
      printf '%s' "${accounts_json}" | jq -r --arg account "${configured_account}" '
        map(select(.account_uuid == $account or .email == $account or .url == $account))
        | .[0].account_uuid // empty
      '
    )"
  else
    selected_account=""
  fi

  if [[ -z "${selected_account}" ]]; then
    selected_account="$(printf '%s' "${accounts_json}" | jq -r '.[0].account_uuid // empty')"
    [[ -n "${selected_account}" ]] || return 1
    replace_private_key "op_account" "${selected_account}" "${PRIVATE_DATA_FILE}"
  fi

  printf '%s\n' "${selected_account}"
}

onepassword_is_ready() {
  local account readiness_item item_id item_json

  command -v op >/dev/null 2>&1 || return 1
  seed_private_data_file

  account="$(choose_onepassword_account)" || return 1
  readiness_item="$(read_private_key "readiness_item" "${PRIVATE_DATA_FILE}")"

  if [[ -n "${readiness_item}" ]]; then
    op item get "${readiness_item}" --account "${account}" --format json >/dev/null 2>&1 || return 1
  else
    item_json="$(op item list --account "${account}" --format json 2>/dev/null || true)"
    item_id="$(printf '%s' "${item_json}" | jq -r '.[0].id // empty')"
    [[ -n "${item_id}" ]] || return 1
    op item get "${item_id}" --account "${account}" --format json >/dev/null 2>&1 || return 1
  fi

  export OP_ACCOUNT="${account}"
  return 0
}

run_public_defaults() {
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  is_ci && return 0

  if [[ -x "${PUBLIC_DEFAULTS_SCRIPT}" ]]; then
    log_section "macOS defaults"
    "${PUBLIC_DEFAULTS_SCRIPT}"
  fi
}

run_public_phase() {
  log_bootstrap_context
  ensure_homebrew
  ensure_chezmoi
  ensure_directories
  seed_private_data_file
  apply_public_dotfiles

  if is_ci; then
    run_brew_bundle "${CI_BREWFILE}"
  else
    ensure_go_toolchain
    ensure_rust_toolchain
    ensure_actrun
    run_brew_bundle "${PUBLIC_BREWFILE}"
    run_public_defaults
  fi
}

run_private_phase() {
  local private_bundle

  log_bootstrap_context
  ensure_homebrew
  ensure_chezmoi
  ensure_directories
  seed_private_data_file

  if ! onepassword_is_ready; then
    log_warn "1Password is not ready. Sign in, unlock it, and rerun ./install.sh."
    return 1
  fi

  apply_private_dotfiles

  if [[ -f "${PUBLIC_BREWFILE}" ]]; then
    run_brew_bundle "${PUBLIC_BREWFILE}"
  fi

  private_bundle="$(mktemp)"
  if render_private_bundle "${private_bundle}"; then
    run_brew_bundle "${private_bundle}"
  else
    log_info "No private Homebrew overlay entries were rendered."
  fi
  rm -f "${private_bundle}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      [[ $# -ge 2 ]] || {
        usage
        exit 1
      }
      PHASE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

case "${PHASE}" in
  auto)
    run_public_phase
    if is_ci; then
      log_success "Completed public bootstrap for CI."
      exit 0
    fi

    if onepassword_is_ready; then
      run_private_phase
      log_success "Completed public bootstrap and private overlay."
    else
      log_warn "Completed the public bootstrap. Sign in to 1Password, then rerun ./install.sh."
    fi
    ;;
  public)
    run_public_phase
    log_success "Completed the public bootstrap."
    ;;
  private)
    run_private_phase
    log_success "Completed the private overlay."
    ;;
  *)
    printf 'Invalid phase: %s\n' "${PHASE}" >&2
    usage
    exit 1
    ;;
esac
