#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go"

source "${GODIR}/scripts/functions.sh"

# Safely exit script
trap cleanup_rgo EXIT INT TERM # perform cleanup on any exit in script

# Define the environment
VERSION="$(echo -e "${1:-"UNKNOWN"}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "${VERSION}" == "" ] && [ "${VERSION}" != "list" ]  && rgo_usage "Invalid VERSION provided."
[ "${VERSION}" != "list" ] && [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && (rgo_usage "Invalid version format";exit 1)

case "${1:-""}" in
  list)
    list_versions
    ;;
  help)
    rgo_usage
    exit 0
    ;;
  "")
    rgo_usage
    exit 1
    ;;
  *)
    while true; do
      echo "rgo will uninstall Go ${VERSION} from ${GODIR}/versions/${VERSION} and any installed Go programs (like gotop)."
      read -r -p "Do you want to continue? [y/n] " yn
      case $yn in
        [Yy]* ) echo "Uninstalling ${VERSION}"; break;;
        [Nn]* ) echo "Will not uninstall ${VERSION}"; exit;;
        * ) echo "Please answer yes or no.";;
      esac
    done

    echo "Removing ${VERSION} from your ${GODIR}/versions directory..."
    # Prevent concurrent rgo usage check
    [ -f "${GODIR}/uninstaller.lock" ] && safe_exit "Another rgo $(cat "${GODIR}/uninstaller.lock") is currently running."

    # Lock the installer to the version specified
    echo "${VERSION}" > "${GODIR}/uninstaller.lock" # prevent concurrent rgo usage locker
    remove_version "$1"
    echo "Removed ${HOME}/go/versions/${1} from your system."
    ;;
esac
