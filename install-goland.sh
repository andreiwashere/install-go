#!/bin/bash

[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.

declare version
declare goland_tar
declare goland_shim
declare checksum_url
declare tar_url
declare goland_checksum
declare goland_checksum_value
declare arch
declare current_shell
declare rc_file
declare GOSCRIPTS
declare GOBIN
declare GOARCH
declare GOROOT
declare GOSHIMS
declare GOOS
declare GOPATH
declare GODIR

GODIR="${HOME:-/home/$(whoami)}/go"
GOOS="$(uname | tr '[:upper:]' '[:lower:]')"
GOSCRIPTS="${GODIR}/scripts"
GOBIN="${GODIR}/bin"
GOARCH="${arch}"
GOROOT="${GODIR}/root"
GOSHIMS="${GODIR}/shims"
GOPATH="${GODIR}/path"

export GOSCRIPTS
export GOBIN
export GOARCH
export GOROOT
export GOSHIMS
export GOOS
export GOPATH

# Help
if [[ "${1:-}" == "-h" || "${1:-}" == "help" || "${1:-}" == "--help" ]]; then
  cat << EOF
Usage: ${0##*/} [version] [options]

This script installs GoLand, an IDE by JetBrains for Go development. It downloads
the specified version of GoLand, verifies its checksum, and sets up a convenient
execution shim. The script also configures necessary environment variables for Go
development.

Arguments:
  version           Specify the version of GoLand to download, e.g., '2023.2.5'.
                    If not provided, defaults to the latest available version.

Options:
  -h, --help, help  Display this help and exit.

Example:
  ${0##*/} 2023.2.5    # Install GoLand version 2023.2.5
  ${0##*/}             # Install the latest version of GoLand

EOF
  exit 1
fi

# Version
version="${1:-'2023.2.5'}"
version_regex='^[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}$'
if ! [[ $version =~ $version_regex ]]; then
  echo "Invalid version specified. Default: ${version}"
  exit 1
fi

# Workspace
goland_home="${GODIR}/land"
mkdir -p "${GODIR}" || { echo "Can't create ${GODIR}."; exit 1; }
mkdir -p "${GODIR}/shims" || { echo "Can't create ${GODIR}/shims."; exit 1; }
mkdir -p "${goland_home}" || { echo "Can't create ${goland_home}."; exit 1; }
mkdir -p "${goland_home}/sessions" || { echo "Can't create ${goland_home}/sessions."; exit 1; }
cd "${goland_home}" || { echo "Can't find ${goland_home}". ; exit 1; }

goland_tar="goland-${version}.tar.gz"
goland_checksum="${goland_tar}.sha256"
checksum_url="https://download.jetbrains.com/go/${goland_checksum}"
tar_url="https://download-cdn.jetbrains.com/go/${goland_tar}"

# Checksum
if [[ ! -f "${goland_checksum}" ]]; then
  curl -f -L "${checksum_url}" -o "${goland_checksum}" || safe_exit "Failed to download ${checksum_url}"
fi
goland_checksum_value="$(sha256sum "${goland_tar}")"

# Tarball
if [[ ! -f "${goland_tar}" ]]; then
  curl -f -L "${tar_url}" -o "${goland_tar}"  || safe_exit "Failed to download ${tar_url}"
fi

# Security Check
if [[ "$(cat "${goland_checksum}")" != "${goland_checksum_value}" ]]; then
  echo "DANGER! Checksums do not match."
  echo
  echo "${goland_tar} = ${goland_checksum_value}"
  echo "${checksum_url} = $(cat "${goland_checksum}")"
  echo
  echo "${goland_checksum_value} != $(cat "${goland_checksum}")"
  echo
  rm -rf "${goland_checksum}"
  rm -rf "${goland_tar}"
  exit 1
fi

# Extract GoLand Tar
tar -zxf "${goland_tar}"

# Create symbolic link
if [[ ! -L "${goland_home}/latest" ]]; then
  GoLandDir=$(find "${GODIR}/land" -type d -name 'GoLand*' -print0 | xargs -0 ls -dt | head -n 1)
  ln -s "${GoLandDir}" "${goland_home}/latest"
fi

# Install the shim
goland_shim="${GOSHIMS}/goland"
[[ -f "${goland_shim}" ]] && rm -f "${goland_shim}"
cat >> "${goland_shim}" <<EOF
#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.
[ "${VERBOSE:-0}" == "1" ] && set -v  # DEVELOPER EXPERIENCE: Print shell input lines as they are read, aiding in debugging.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.

GODIR="${HOME:-"/home/$(whoami)"}/go"

if [ ! -L "${GODIR}/land/latest" ]; then
  GoLandDir=$(find "${GODIR}/land" -type d -name 'GoLand*' -print0 | xargs -0 ls -dt | head -n 1)
  if [ -d "${GoLandDir}" ]; then
    ln -s "${GoLandDir}" "${GODIR}/land/latest"
  fi
fi

safe_exit() { echo "${1:-UnexpectedError}" ; exit 1; }

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
    if [[ "$response" == "yes" ]]; then
      find "$LOG_DIR" -type f -name '*.log' -mtime +7 -size +1G -exec rm {} \;
      echo "$(echo "$large_files" | wc -l) Large GoLand session file(s) deleted."
    else
      echo "No files were deleted."
    fi
  fi
}

cleanup_logs

nohup "$GOLAND_SCRIPT" > "$LOG_FILE" 2>&1 &

EOF

# Make shim executable
chmod +x "${goland_shim}"

# Install shim into go bin
mkdir -p "${GOBIN}"

[[ -d "${GOBIN}" ]] && { cd "${GOBIN}" || { echo "Can't CD into ${GOBIN}."; exit 1; } }
[[ ! -L "${GOBIN}/goland" ]] && ln -s "${goland_shim}" "${GOBIN}/goland"

arch="$(uname -m)"
if [[ "$(uname -m)" == "x86_64" ]]; then
  arch="amd64"
fi

current_shell=$(ps -p $$ -oargs=)
rc_file=""

if [[ "${current_shell}" == *bash* ]]; then
  rc_file="${HOME}/.bashrc"
elif [[ "${current_shell}" == *zsh* ]]; then
  rc_file="${HOME}/.zshrc"
else
  echo "Unsupported shell: ${current_shell}"
  exit 0
fi

# Check if go_bin is in the PATH
[[ ":${PATH}:" != *":${GOBIN}:"* ]] && echo "export PATH=\"${GOBIN}:\$PATH\"" | tee -a "${rc_file}" > /dev/null

# Ensure the rc file has the Go definitions
! grep -q '^export GOSCRIPTS' "${rc_file}" && echo "export GOSCRIPTS=\"${GODIR}/scripts\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOBIN' "${rc_file}" && echo "export GOBIN=\"${GODIR}/bin\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOARCH' "${rc_file}" && echo "export GOARCH=\"${arch}\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOROOT' "${rc_file}" && echo "export GOROOT=\"${GODIR}/root\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOSHIMS' "${rc_file}" && echo "export GOSHIMS=\"${GODIR}/shims\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOOS' "${rc_file}" && echo "export GOOS=\"$(uname | tr '[:upper:]' '[:lower:]')\"" | tee -a "${rc_file}" > /dev/null
! grep -q '^export GOPATH' "${rc_file}" && echo "export GOPATH=\"${GODIR}/path\"" | tee -a "${rc_file}" > /dev/null
