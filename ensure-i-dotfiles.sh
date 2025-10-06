#!/usr/bin/env bash
set -euo pipefail

prompt_accept() {
  local prompt="$1"
  local reply=""
  local bold=""
  local reset=""

  if [[ -t 0 || -t 1 || -r /dev/tty ]]; then
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
    printf "[x] cannot prompt for confirmation (no tty)\n" >&2
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

resolve_path() {
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

ensure_link() {
  local src="$1"
  local dst="$2"

  if [[ ! -e "${src}" ]]; then
    printf "[x] expected %s to exist\n" "${src}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${dst}")"

  local resolved_src
  resolved_src="$(resolve_path "${src}")"

  if [[ -L "${dst}" ]]; then
    local resolved_dst
    resolved_dst="$(resolve_path "${dst}")"

    if [[ "${resolved_dst}" == "${resolved_src}" ]]; then
      printf "[ok] %s already symlinks to %s\n" "${dst}" "${src}"
      return
    fi

    printf "[warn] %s currently points to %s\n" "${dst}" "${resolved_dst}"
    if prompt_accept "Fix ${dst} to point to ${src}?"; then
      rm "${dst}"
      printf "[info] removed existing symlink %s\n" "${dst}"
    else
      printf "[x] leaving %s unchanged\n" "${dst}" >&2
      exit 1
    fi
  elif [[ -e "${dst}" ]]; then
    if cmp -s "${dst}" "${src}"; then
      rm "${dst}"
      printf "[info] removed existing %s because it matched %s\n" "${dst}" "${src}"
    else
      local backup="${dst}.backup.$(date +%Y%m%d%H%M%S)"
      mv "${dst}" "${backup}"
      printf "[info] moved existing %s to %s\n" "${dst}" "${backup}"
    fi
  fi

  ln -s "${src}" "${dst}"
  printf "[ok] created symlink %s -> %s\n" "${dst}" "${src}"
}

ensure_link "${HOME}/config/i/ssh/config" "${HOME}/.ssh/config"
ensure_link "${HOME}/config/i/git/.gitconfig" "${HOME}/.gitconfig"
