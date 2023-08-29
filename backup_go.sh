#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -o pipefail  # SECURITY: Ensure that piped commands in this script successfully execute.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go"

source "${GODIR}/scripts/functions.sh"

trap cleanup_bgo EXIT INT TERM

if [ ! -d "${GODIR}" ]; then
  echo "You must have Go installed at ${GODIR} via the github.com/andreiwashere/install-go package."
  exit 1
fi

[ -f "${GODIR}/backup.lock" ] && safe_exit "Already running..."

DIR="${GODIR}/backups"

[ ! -d "${DIR}" ] && mkdir -p "${DIR}"
{ [ -d "${DIR}" ] && echo "Checked directory: ${DIR}"; } || safe_exit "Failed to create directory ${DIR}"

create_backup "${GODIR}"
