#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

GO_DIR="/go/versions"
SYMLINK_DIR="/go"

list_versions() {
    echo "Installed Go versions:"
    for dir in "${GO_DIR}"/*; do
        if [[ -d "${dir}" ]]; then
            version=$(basename "${dir}")
            echo "- ${version} # Execute this: sudo $0 ${version}"
        fi
    done
    echo
}

switch_version() {
    target_version="$1"

    if [[ ! -d "${GO_DIR}/${target_version}" ]]; then
        echo "Error: Version ${target_version} not installed."
        exit 1
    fi

    current_version=$(readlink "${SYMLINK_DIR}/root" | awk -F'/' '{print $NF}')

    rm -f "${SYMLINK_DIR}/root" "${SYMLINK_DIR}/bin" "${SYMLINK_DIR}/path"

    ln -s "${GO_DIR}/${target_version}/src" "${SYMLINK_DIR}/root"
    ln -s "${GO_DIR}/${target_version}/src/bin" "${SYMLINK_DIR}/bin"
    ln -s "${GO_DIR}/${target_version}" "${SYMLINK_DIR}/path"

    echo "Updated symlinks from \"/go/versions/${current_version}\" to \"/go/versions/${target_version}\"."

    GOROOT="/go/versions/${target_version}/src" "${SYMLINK_DIR}/bin/go" version
}

case "$1" in
    list)
        list_versions
        ;;
    [0-9]*)
        switch_version "$1"
        ;;
    *)
        echo "Usage:"
        echo "   sudo $0 list               - List installed Go versions"
        echo "   sudo $0 <version>          - Switch to the specified Go version"
        ;;
esac
