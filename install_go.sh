#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

GODIR="${HOME:-"/home/$(whoami)"}/go" # where all things go go

# Create the Go Directory
[ -d "${GODIR}" ] || mkdir -p "${GODIR}" || { echo "Failed to mkdir the GODIR ${GODIR}"; exit 1; }

# Load the functions
source "${GODIR}/scripts/functions.sh"

# Safely exit script
trap cleanup_igo EXIT INT TERM # perform cleanup on any exit in script

# No Windows support
[ "$(uname)" != "Linux" ] && safe_exit "HOLD UP: igo is only supported on Linux."

# Prevent concurrent igo usage check
[ -f "${GODIR}/installer.lock" ] && safe_exit "Another installation $(cat "${GODIR}/installer.lock") is currently running."

# Ensure proper argument count or show usage details
[ "$#" -lt 1 ] || [ "$#" -gt 3 ] && igo_usage "Missing arguments called VERSION GOOS and GOARCH." # igo VERSION [ GOOS ] [ GOARCH ]

# Define the environment
VERSION="$(echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "${VERSION}" == "" ] && igo_usage "Invalid VERSION provided."
echo "Version being checked: ${VERSION}"
[[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && igo_usage "Invalid version format"

# Set up the system for Go
export GOOS="${2:-linux}"
export GOARCH="${3:-amd64}"

# Lock the installer to the version specified
echo "${VERSION}" > "${GODIR}/installer.lock" # prevent concurrent igo usage locker

# Check if the version is already installed
[ -f "${GODIR}/versions/${VERSION}/installed.lock" ] && safe_exit "Already have Go ${VERSION} installed at /go/versions/${VERSION}"

# Install the Go Version File
if [ ! -f "${GODIR}/version" ]; then
  echo "${VERSION}" > "${GODIR}/version"
  { grep -qxF "${VERSION}" "${GODIR}/version" && echo "Installing Go ${VERSION}..."; } || safe_exit "Can't install Go ${VERSION}!"
else
  echo "Existing active GO installation: $(cat "${GODIR}/version")"
  echo "Will install this version of Go next to $(cat "${GODIR}/version")..."
fi

# Go to the Go Directory ¬‿¬
cd "${GODIR}"

# Name of the downloaded archive
GO_DOWNLOAD_TARBALL="go${VERSION}.${GOOS}-${GOARCH}.tar.gz"

# Ensure the downloads directory exists
[ -d "${GODIR}/downloads" ] || mkdir -p "${GODIR}/downloads" || safe_exit "Unable to create ${GODIR}/downloads directory"

# Download Go archive
if [ ! -f "${GODIR}/downloads/${GO_DOWNLOAD_TARBALL}" ]; then
  curl -L -o "${GODIR}/downloads/${GO_DOWNLOAD_TARBALL}" "https://go.dev/dl/${GO_DOWNLOAD_TARBALL}" || safe_exit "Failed to download ${GO_DOWNLOAD_TARBALL}"
fi
{ [ -f "${GODIR}/downloads/${GO_DOWNLOAD_TARBALL}" ] && echo "Downloaded file: ${GO_DOWNLOAD_TARBALL}"; } || safe_exit "Failed to download ${GO_DOWNLOAD_TARBALL}"

# Create the target directory for the version mkdir -p "${GODIR}/versions/${VERSION}"
[ ! -d "${GODIR}/versions/${VERSION}" ] && mkdir -p "${GODIR}/versions/${VERSION}"
[ -d "${GODIR}/versions/${VERSION}" ] || safe_exit "Failed to create the ${GODIR}/versions/${VERSION} directory."

# Extract the tarball
tar -C "${GODIR}/versions/${VERSION}" -xzf "${GODIR}/downloads/${GO_DOWNLOAD_TARBALL}"
{ [ -d "${GODIR}/versions/${VERSION}/go" ] && echo "Extracted ${GO_DOWNLOAD_TARBALL}: ${GODIR}/versions/${VERSION}/go"; } || safe_exit "Failed to extract ${GO_DOWNLOAD_TARBALL}"

# Install the Go Shim
mv "${GODIR}/versions/${VERSION}/go/bin/go" "${GODIR}/versions/${VERSION}/go/bin/go.${VERSION}"
ln -s "${GODIR}/shims/go" "${GODIR}/versions/${VERSION}/go/bin/go"

# Install the GoFMT Shim
mv "${GODIR}/versions/${VERSION}/go/bin/gofmt" "${GODIR}/versions/${VERSION}/go/bin/gofmt.${VERSION}"
ln -s "${GODIR}/shims/gofmt" "${GODIR}/versions/${VERSION}/go/bin/gofmt"

# Set up the system for managed Go environment
export GOROOT="${GODIR}/root"
export GOPATH="${GODIR}/path"
export GOBIN="${GODIR}/bin"
export GOSHIMS="${GODIR}/shims"
export GOSCRIPTS="${GODIR}/scripts"

# Create symlink for GOROOT
[ -L "${GOROOT}" ] || ln -s "${GODIR}/versions/${VERSION}/go" "${GOROOT}"
{ [ -L "${GOROOT}" ] && echo "Configure GOROOT: ${GOROOT} -> ${GODIR}/versions/${VERSION}/go"; } || safe_exit "Failed to create GOROOT symlink"

# Ensure GOBIN is not a directory (bug caused from install_goland.sh)
[ -d "${GOBIN}" ] && mv "${GOBIN}" "${GOBIN}.bak" && echo "Moved ${GOBIN} to ${GOBIN}.bak"

# Create symlink for GOBIN
[ -L "${GOBIN}" ] || ln -s "${GODIR}/versions/${VERSION}/go/bin" "${GOBIN}"
{ [ -L "${GOBIN}" ] && echo "Configure GOBIN: ${GOBIN} -> ${GODIR}/versions/${VERSION}/go/bin"; } || safe_exit "Failed to create GOBIN symlink"

# Create symlink for GOPATH
[ -L "${GOPATH}" ] || ln -s "${GODIR}/versions/${VERSION}" "${GOPATH}"
{ [ -L "${GOPATH}" ] && echo "Configure GOPATH: ${GOPATH} -> ${GODIR}/versions/${VERSION}"; } || safe_exit "Failed to create GOPATH symlink"

BASHRC="${HOME:-"/home/$(whoami)"}/.bashrc"
[ -f "${BASHRC}" ] && set_env_vars "${BASHRC}"

ZSHRC="${HOME:-"/home/$(whoami)"}/.zshrc"
[ -f "${ZSHRC}" ] && set_env_vars "${ZSHRC}"

export PATH=$GOSHIMS:$GOBIN:$GOSCRIPTS:$PATH

GO_VERSION_OUTPUT=$(GOROOT="${GODIR}/versions/${VERSION}/go" GOPATH="${GODIR}/versions/${VERSION}" GOBIN="${GODIR}/versions/${VERSION}/go/bin" GOOS="${GOOS}" GOARCH="${GOARCH}" "${GODIR}/versions/${VERSION}/go/bin/go.${VERSION}" version)

INSTALLED_VERSION=$(echo "${GO_VERSION_OUTPUT}" | awk '{print $3}' | sed 's/go//')
INSTALLED_OS=$(echo "${GO_VERSION_OUTPUT}" | awk '{print $4}' | awk -F/ '{print $1}')
INSTALLED_ARCH=$(echo "${GO_VERSION_OUTPUT}" | awk '{print $4}' | awk -F/ '{print $2}')

if [[ "${INSTALLED_VERSION}" == "${VERSION}" && "${INSTALLED_OS}" == "${GOOS}" && "${INSTALLED_ARCH}" == "${GOARCH}" ]]; then
  echo "Sanity check: PASS"
else
  echo "Sanity check: FAIL"
  echo "  Mismatch in installed Go version!"
  echo "  Expected: go${VERSION} ${GOOS}/${GOARCH}"
  echo "  Got: go${INSTALLED_VERSION} ${INSTALLED_OS}/${INSTALLED_ARCH}"
  exit 1
fi

declare -A packages=( ["gotop"]="github.com/cjbassi/gotop" ["go-generate-password"]="github.com/m1/go-generate-password/cmd/go-generate-password" ["bombardier"]="github.com/codesenberg/bombardier" )
for pkg in "${!packages[@]}"; do
  GOROOT="${GODIR}/versions/${VERSION}/go" GOPATH="${GODIR}/versions/${VERSION}" GOBIN="${GODIR}/versions/${VERSION}/go/bin" GOOS="${GOOS}" GOARCH="${GOARCH}" "${GODIR}/versions/${VERSION}/go/bin/go.${VERSION}" install "${packages[$pkg]}@latest"
  { [ -f "${GODIR}/versions/${VERSION}/go/bin/${pkg}" ] && echo "Installed ${pkg}"; } || safe_exit "Failed to install ${pkg}"
done

touch "${GODIR}/versions/${VERSION}/installer.lock"

rm -rf "${GODIR}/installer.lock"

while true; do
    read -r -t 17 -p "Do you want to reload your shell (exec \"$SHELL\")? [y/n] " yn
    case $yn in
        [Yy]* ) source_shell_config; break;;
        [Nn]* ) echo ; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
