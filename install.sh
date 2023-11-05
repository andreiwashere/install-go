#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.

GODIR="${HOME:-"/home/$(whoami)"}/go" # where all things go go

safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo "${msg}"
  exit 1
}

[ -d "${GODIR}" ] && [ -f "${GODIR}/shims/go" ] && safe_exit "Already installed at ${GODIR}."

# No Windows support
[ "$(uname)" != "Linux" ] && safe_exit "HOLD UP: igo is only supported on Linux."

# Extract the operating system and machine details
os=$(uname -s)
machine=$(uname -m)
goos=""
goarch=""

# Translate them to GOOS and GOARCH values
case $os in
    Linux)     goos="linux";;
    Darwin)    goos="darwin";;
    WindowsNT) goos="windows";;
    *)         goos="unknown";;
esac

case $machine in
    x86_64)  goarch="amd64";;
    i386)    goarch="386";;
    i686)    goarch="386";;
    armv7l)  # On many systems, armv7 will report as armv7l
        goarch="arm"
        GOARM="7"
        export GOARM
        ;;
    arm*)
        # Defaulting to ARMv6 for all other ARM versions (this may or may not suit your needs)
        goarch="arm"
        GOARM="6"
        export GOARM
        ;;
    aarch64) goarch="arm64";;
    *)       goarch="unknown";;
esac

# Set up the system for managed Go environment
export GOOS=$goos
export GOARCH=$goarch
export GOROOT="${GODIR}/root"
export GOPATH="${GODIR}/path"
export GOBIN="${GODIR}/bin"
export GOSHIMS="${GODIR}/shims"
export GOSCRIPTS="${GODIR}/scripts"

# Create the Go Directory
mkdir -p "${GODIR}/backups" "${GODIR}/manifests" "${GODIR}/scripts" "${GODIR}/shims"

download_script() {
  local src="${1}"
  local pkg="${2}"
  local file="${3}"

  if [ ! -f "${pkg}" ] || [ ! -L "${pkg}" ]; then
    if [ -f "${GODIR}/install-go/${file}" ]; then
      [ -L "${pkg}" ] || ln -s "${GODIR}/install-go/${file}" "${pkg}"
    else
      curl -L -o "${pkg}" "${src}" || safe_exit "Failed to download ${src}"
    fi
  else
    echo "Already have $(basename "${pkg}") installed at ${pkg}!"
  fi
}

set_env_vars() {
    local target_file="${1}"
    declare -A env_vars=(
        ["GOOS"]=$GOOS
        ["GOARCH"]=$GOARCH
        ["GOPATH"]=$GOPATH
        ["GOROOT"]=$GOROOT
        ["GOBIN"]=$GOBIN
        ["GOSHIMS"]=$GOSHIMS
        ["GOSCRIPTS"]=$GOSCRIPTS
    )
    echo "Patching file: ${target_file}"

    for var in "${!env_vars[@]}"; do
        if ! grep -qxF "export ${var}=${env_vars[$var]}" "$target_file"; then
            echo "export ${var}=${env_vars[$var]}" >> "$target_file" || safe_exit "Failed to set ${var} in $target_file"
            echo "Set ${var} in $target_file to ${env_vars[$var]}"
        fi
    done

    if ! grep -qxF "export PATH=\$GOBIN:\$GOSHIMS:\$GOSCRIPTS:\$PATH" "$target_file"; then
        echo "export PATH=\$GOBIN:\$GOSHIMS:\$GOSCRIPTS:\$PATH" >> "$target_file" || safe_exit "Failed to append PATH in $target_file"
        echo "Appended PATH in $target_file"
    fi

    echo "Done patching file: ${target_file}"
}

download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/install_go.sh" "${GODIR}/scripts/igo" "install_go.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/switch_go.sh" "${GODIR}/scripts/sgo" "switch_go.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/backup_go.sh" "${GODIR}/scripts/bgo" "backup_go.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/remove_go.sh" "${GODIR}/scripts/rgo" "remove_go.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/functions.sh" "${GODIR}/scripts/functions.sh" "functions.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/shim_go.sh" "${GODIR}/shims/go" "shim_go.sh"
download_script "https://raw.githubusercontent.com/andreiwashere/install-go/main/shim_gofmt.sh" "${GODIR}/shims/gofmt" "shim_gofmt.sh"

chmod +x "${GODIR}/shims/go"
chmod +x "${GODIR}/shims/gofmt"
chmod +x "${GODIR}/scripts/bgo"
chmod +x "${GODIR}/scripts/igo"
chmod +x "${GODIR}/scripts/rgo"
chmod +x "${GODIR}/scripts/sgo"

BASHRC="${HOME:-"/home/$(whoami)"}/.bashrc"
[ -f "${BASHRC}" ] && set_env_vars "${BASHRC}"

ZSHRC="${HOME:-"/home/$(whoami)"}/.zshrc"
[ -f "${ZSHRC}" ] && set_env_vars "${ZSHRC}"

export PATH=$GOSHIMS:$GOBIN:$GOSCRIPTS:$PATH

current_shell=$(basename "${SHELL:-"/bin/bash"}")

case "$current_shell" in
  bash)
    rcfile="${HOME}/.bashrc"
    ;;
  zsh)
    rcfile="${HOME}/.zshrc"
    ;;
  *)
    echo "Unsupported shell: ${current_shell}."
    exit 1
    ;;
esac

if [ -f "$rcfile" ]; then
  exec "${SHELL:-"/bin/bash"}"
else
  echo "$rcfile not found."
fi


