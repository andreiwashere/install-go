#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go" # where all things go go

# Create the Go Directory
[ -d "${GODIR}" ] || mkdir -p "${GODIR}" || { echo "Failed to mkdir the GODIR ${GODIR}"; exit 1; }

# Load the functions
source "${GODIR}/scripts/functions.sh"

case "$1" in
    list)
        list_versions
        ;;
    qlist)
        list_versions_quiet
        ;;
    [0-9]*)
        switch_version "$1"
        ;;
    *)
        echo "Usage:"
        echo "   $0 list               - List installed Go versions"
        echo "   $0 <version>          - Switch to the specified Go version"
        ;;
esac
