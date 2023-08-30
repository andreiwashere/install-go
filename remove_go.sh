#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go"

source "${GODIR}/scripts/functions.sh"

case "$1" in
  list)
    list_versions
    ;;
  help)
    echo "Usage:"
    echo "   $0 help               - Show this help message"
    echo "   $0 <version>          - Remove the specified Go version"
    exit 0
    ;;
  "")
    echo "Usage:"
    echo "   $0 help               - Show this help message"
    echo "   $0 <version>          - Remove the specified Go version"
    exit 1
    ;;
  *)
    remove_version "$1"
    ;;
esac
