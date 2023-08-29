#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

# No Windows support
[ "$(uname)" != "Linux" ] && safe_exit "HOLD UP: igo is only supported on Linux."

GODIR="${HOME:-"/home/$(whoami)"}/go" # where all things go go

# Create the Go Directory
[ -d "${GODIR}" ] || mkdir -p "${GODIR}/{backups,manifests,scripts}" || { echo "Failed to mkdir the GODIR ${GODIR}"; exit 1; }

igo_src="https://raw.githubusercontent.com/andreiwashere/install-go/install_go.sh"
igo_pkg="${GODIR}/scripts/igo"
{ [ ! -f "${igo_pkg}" ] && wget --https-only --secure-protocol=auto --no-cache -O "${igo_pkg}" "${igo_src}" < /dev/null > /dev/null 2>&1; } || safe_exit "Downloading ${igo_src}: FAILED"

sgo_src="https://raw.githubusercontent.com/andreiwashere/install-go/switch_go.sh"
sgo_pkg="${GODIR}/scripts/sgo"
{ [ ! -f "${sgo_pkg}" ] && wget --https-only --secure-protocol=auto --no-cache -O "${sgo_pkg}" "${sgo_src}" < /dev/null > /dev/null 2>&1; } || safe_exit "Downloading ${sgo_src}: FAILED"

bgo_src="https://raw.githubusercontent.com/andreiwashere/install-go/backup_go.sh"
bgo_pkg="${GODIR}/scripts/bgo"
{ [ ! -f "${bgo_pkg}" ] && wget --https-only --secure-protocol=auto --no-cache -O "${bgo_pkg}" "${bgo_src}" < /dev/null > /dev/null 2>&1; } || safe_exit "Downloading ${bgo_src}: FAILED"

functions_src="https://raw.githubusercontent.com/andreiwashere/install-go/functions.sh"
functions_file="${GODIR}/scripts/functions.sh"
{ [ ! -f "${functions_file}" ] && wget --https-only --secure-protocol=auto --no-cache -O "${functions_file}" "${functions_src}" < /dev/null > /dev/null 2>&1; } || safe_exit "Downloading ${functions_src}: FAILED"

current_shell=$(basename "${SHELL:-"/bin/bash"}")

case "$current_shell" in
  bash)
    if [ -f "${HOME}/.bashrc" ]; then
      ! grep -qxF "export PATH=${GODIR}/scripts" "${HOME}/.bashrc" && echo "export PATH=${GODIR}/scripts:\$PATH" >> "${HOME}/.bashrc"
      source "${HOME}/.bashrc"
      echo "Sourced ${HOME}/.bashrc."
    else
      echo "${HOME}/.bashrc not found."
    fi
    ;;
  zsh)
    if [ -f "${HOME}/.zshrc" ]; then
      ! grep -qxF "export PATH=${GODIR}/scripts" "${HOME}/.zshrc" && echo "export PATH=${GODIR}/scripts:\$PATH" >> "${HOME}/.zshrc"
      source "${HOME}/.zshrc"
      echo "Sourced ${HOME}/.zshrc."
    else
      echo "${HOME}/.zshrc not found."
    fi
    ;;
  *)
    echo "Unsupported shell: ${current_shell}."
    ;;
esac

