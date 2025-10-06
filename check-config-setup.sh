#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
expected_root="${HOME}/config"

errors=0

log_error() {
  printf "[x] %s\n" "$1"
  errors=$((errors + 1))
}

log_success() {
  printf "[ok] %s\n" "$1"
}

log_warn() {
  printf "[warn] %s\n" "$1"
}

resolve_path() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

prompt_yes() {
  local prompt="$1"
  local reply=""

  local bold=""
  local reset=""
  if [[ -t 0 ]] || [[ -t 1 ]] || [[ -r /dev/tty ]]; then
    bold=$'\033[1m'
    reset=$'\033[0m'
  fi

  local choices="Press ${bold}A${reset} (Accept) / ${bold}N${reset} (No)"
  local input_tty=""

  if [[ -t 0 ]]; then
    input_tty=""
  elif [[ -r /dev/tty && -w /dev/tty ]]; then
    input_tty="/dev/tty"
  else
    return 1
  fi

  while true; do
    if [[ -n "${input_tty}" ]]; then
      printf "%s\n  %s: " "$prompt" "$choices" > "${input_tty}"
      if IFS= read -rsn1 reply < "${input_tty}"; then
        :
      else
        reply=""
      fi
      printf "\n" > "${input_tty}"
    else
      printf "%s\n  %s: " "$prompt" "$choices"
      if IFS= read -rsn1 reply; then
        :
      else
        reply=""
      fi
      printf "\n"
    fi

    case "$reply" in
      a|A) return 0 ;;
      n|N|$'\n'|$'\r'|"") return 1 ;;
      *)
        if [[ -n "${input_tty}" ]]; then
          printf "Please press A to accept or N to skip.\n" > "${input_tty}"
        else
          printf "Please press A to accept or N to skip.\n"
        fi
        ;;
    esac
  done
}

check_repo_location() {
  if [[ "${repo_root}" != "${expected_root}" ]]; then
    log_error "repo is at ${repo_root}, expected ${expected_root}"
  else
    log_success "repo located at ${expected_root}"
  fi
}

ensure_symlink() {
  local link_path="$1"
  local expected_target="$2"
  local label="$3"

  if [[ ! -e "${expected_target}" ]]; then
    log_error "expected target missing for ${label}: ${expected_target}"
    return
  fi

  local resolved_expected
  if ! resolved_expected="$(resolve_path "${expected_target}")"; then
    log_error "failed to resolve expected target for ${label}: ${expected_target}"
    return
  fi

  if [[ -L "${link_path}" ]]; then
    local actual_target
    if ! actual_target="$(resolve_path "${link_path}")"; then
      log_error "failed to resolve ${label} symlink: ${link_path}"
      return
    fi

    if [[ "${actual_target}" == "${resolved_expected}" ]]; then
      log_success "${label} -> ${expected_target}"
      return
    fi

    log_warn "${label} currently points to ${actual_target}"
  elif [[ -e "${link_path}" ]]; then
    log_warn "${label} exists but is not a symlink: ${link_path}"
  else
    log_warn "${label} symlink missing: ${link_path}"
  fi

  if prompt_yes "Fix ${label} to point to ${expected_target}?"; then
    local parent_dir
    parent_dir="$(dirname "${link_path}")"
    mkdir -p "${parent_dir}"

    if [[ -e "${link_path}" || -L "${link_path}" ]]; then
      rm -rf "${link_path}"
    fi

    if ln -s "${expected_target}" "${link_path}"; then
      log_success "Updated ${label} -> ${expected_target}"
    else
      log_error "failed to create symlink for ${label}: ${link_path}"
    fi
  else
    log_error "${label} incorrect; expected ${expected_target}"
  fi
}

main() {
  check_repo_location

  ensure_symlink "${HOME}/Library/Application Support/Cursor/User/settings.json" "${repo_root}/cursor/settings.json" "Cursor settings.json"
  ensure_symlink "${HOME}/Library/Application Support/Cursor/User/keybindings.json" "${repo_root}/cursor/keybindings.json" "Cursor keybindings.json"
  ensure_symlink "${HOME}/.config/karabiner.edn" "${repo_root}/karabiner/karabiner.edn" "Karabiner config"
  ensure_symlink "${HOME}/.config/fish/config.fish" "${repo_root}/fish/config.fish" "Fish config"
  ensure_symlink "${HOME}/.config/fish/fn.fish" "${repo_root}/fish/fn.fish" "Fish fn.fish"

  if [[ ${errors} -eq 0 ]]; then
    printf "\n✔️ you are setup\n"
  else
    printf "\nFound %d issue(s). Fix them and rerun task setup.\n" "${errors}"
    exit 1
  fi
}

main "$@"
