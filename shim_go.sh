#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go"

source "${GODIR}/scripts/functions.sh"

get_go_binary_path_for_version() {
    local version="$1"
    if [ ! -f "${GODIR}/versions/${version}/go/bin/go.${version}" ]; then
      local GOVERSION=""
      [ -f "$PWD/.go_version" ] && GOVERSION="$(cat "$PWD/.go_version")"

    else
      echo "${GODIR}/versions/${version}/go/bin/go.${version}"
    fi
}

find_version() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.go_version" ]]; then
            cat "$dir/.go_version"
            return
        fi
        dir="$(dirname "$dir")"
    done

    if [ ! -f "${GODIR}/version" ]; then
        safe_exit "No global Go version installed at ${GODIR}/version."
    fi
    cat "${GODIR}/version"
}

version="$(find_version)"
if [ "${version}" == "" ]; then
    safe_exit "Invalid version detected."
fi

# Invoke the real go binary with any arguments passed to the shim
GOBINARY="$(get_go_binary_path_for_version "${version}")"
[ "${GOBINARY}"  == "" ] && safe_exit "You're using a .go_version override of ${version} but it isn't installed yet. You can use: $(sgo qlist)"

GOBIN="${GODIR}/versions/${version}/go/bin"
GOROOT="${GODIR}/versions/${version}/go"
GOPATH="${GODIR}/versions/${version}"

export GOBIN
export GOROOT
export GOPATH

exec "${GOBINARY}" "$@"

