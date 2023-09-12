#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go"

if [ ! -L "${GODIR}/land/latest" ]; then
  GoLandDir=$(find "${GODIR}/land" -type d -name 'GoLand*' | xargs ls -dt | head -n 1)
  if [ -d "${GoLandDir}" ]; then
    ln -s "${GoLandDir}" "${GODIR}/land/latest"
  fi
fi

safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo "${msg}"
  exit 1
}

GOLAND_SCRIPT="${GODIR}/land/latest/bin/goland.sh"
[ ! -f "${GOLAND_SCRIPT}" ] && safe_exit "No such ${GOLAND_SCRIPT} to execute."

LOG_DIR="${GODIR}/land/sessions"
[ ! -d "${GODIR}/land/sessions" ] && mkdir -p "${GODIR}/land/sessions"

LOG_FILE="$LOG_DIR/$(date +'%Y.%m.%d.%H.%M.%S').log"
[ -f "${LOG_FILE}" ] && mv "${LOG_FILE}" "$LOG_DIR/$(date +'%Y.%m.%d.%H.%M.%S').existing.log"

cleanup_logs() {
  find "$LOG_DIR" -type f -name '*.log' -mtime +90 -exec rm {} \;
  large_files=$(find "$LOG_DIR" -type f -name '*.log' -mtime +7 -size +1G)
  if [ -n "$large_files" ]; then
    available_space_gb=$(df -BG "${LOG_DIR}" | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "Found large GoLand session files that are older than 7 days and larger than 1GB:"
    echo "$large_files"
    echo "Available disk space in ${LOG_DIR} is ${available_space_gb}GB."
    read -t 12 -p "Do you want to delete these files? (yes/no): " response
    if [ "$response" = "yes" ]; then
      find "$LOG_DIR" -type f -name '*.log' -mtime +7 -size +1G -exec rm {} \;
      echo "$(echo "$large_files" | wc -l) Large GoLand session file(s) deleted."
    else
      echo "No files were deleted."
    fi
  fi
}

cleanup_logs

nohup "$GOLAND_SCRIPT" > "$LOG_FILE" 2>&1 &
