#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Fatal Error: Missing arguments called VERSION GOOS and GOARCH."
  echo "Usage: "
  echo "       $0 VERSION GOOS GOARCH"
  echo
  echo "  $0 1.20.0                      # Linux amd64"
  echo "  $0 1.20.0 darwin amd64         # MacOS amd64"
  echo "  $0 1.20.0 windows              # Windows amd64"
  echo "  $0 1.20.0 windows amd64        # Windows amd64"
  echo
  echo " (!) at least 1 argument is required, which is the GO VERSION argument"
  echo " (!) if only 2 arguments are provided, then the 2nd argument will be assigned to to GOOS variable"
  echo " (!) if all 3 arguments are provided, GO VERSION, GOOS, and GOARCH will be defined in that order"
  echo
  exit 1
fi

VERSION="${1:-1.20.0}"
export GOOS="${2:-linux}"
export GOARCH="${3:-amd64}"

if [ -f "/go/versions/${VERSION}/installer.lock" ]; then
  echo "Already have Go ${VERSION} installed at /go/versions/${VERSION}"
  exit 1
fi

safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo $msg
  exit 1
}

# Create the Go Directory
mkdir -p /go
[ -d /go ] && echo "Created directory: /go" || safe_exit "Failed to create directory /go"

# Install the Go Version File
if [ ! -f /go/version ]; then
  echo "${VERSION}" > /go/version
  grep -qxF "${VERSION}" /go/version && echo "Installing Go ${VERSION}..." || safe_exit "Can't install Go ${VERSION}!"
else
  echo "Existing active GO installation: $(cat /go/version)"
  echo "Will install this version of Go next to $(cat /go/version)..."
fi

# Go to the Go Directory ¬‿¬
cd /go

GO_DOWNLOAD_TARBALL=go${VERSION}.${GOOS}-${GOARCH}.tar.gz

# Download Go
[ ! -f "/go/${GO_DOWNLOAD_TARBALL}" ] && wget --no-cache "https://go.dev/dl/${GO_DOWNLOAD_TARBALL}" < /dev/null > /dev/null 2>&1 || safe_exit "Downloading https://go.dev/dl/${GO_DOWNLOAD_TARBALL} failed: NOT FOUND"
[ -f "/go/${GO_DOWNLOAD_TARBALL}" ] && echo "Downloaded file: ${GO_DOWNLOAD_TARBALL}" || safe_exit "Failed to download ${GO_DOWNLOAD_TARBALL}"

# Create the target directory for the version
mkdir -p "/go/versions/${VERSION}"
[ -d "/go/versions/${VERSION}" ] && echo "Prepared directory: /go/versions/${VERSION}" || safe_exit "Failed to create directory /go/versions/${VERSION}"

# Extract the tarball
tar -C "/go/versions/${VERSION}" -xzf "${GO_DOWNLOAD_TARBALL}"
[ -d "/go/versions/${VERSION}/go" ] && echo "Extracted ${GO_DOWNLOAD_TARBALL}: /go/versions/${VERSION}/go" || safe_exit "Failed to extract ${GO_DOWNLOAD_TARBALL}"

[ -f "/go/${GO_DOWNLOAD_TARBALL}" ] && rm -f "/go/${GO_DOWNLOAD_TARBALL}"
[ ! -f "/go/${GO_DOWNLOAD_TARBALL}" ] && echo "Deleted ${GO_DOWNLOAD_TARBALL}" || safe_exit "Failed to delete ${GO_DOWNLOAD_TARBALL}"

mv "/go/versions/${VERSION}/go" "/go/versions/${VERSION}/src"
[ -d "/go/versions/${VERSION}/src" ] && echo "Moved /go/versions/${VERSION}/go -> /go/versions/${VERSION}/src" || safe_exit "Failed to move /go/versions/${VERSION}/go -> /go/versions/${VERSION}/src"

export GOROOT=/go/root
export GOPATH=/go/path
export GOBIN=/go/bin

[ -L "${GOROOT}" ] || ln -s "/go/versions/${VERSION}/src" "${GOROOT}"
[ -L "${GOROOT}" ] && echo "Configure GOROOT: ${GOROOT} -> /go/versions/${VERSION}/src" || safe_exit "Failed to create GOROOT symlink"

[ -L "${GOBIN}" ] || ln -s "/go/versions/${VERSION}/src/bin" "${GOBIN}"
[ -L "${GOBIN}" ] && echo "Configure GOBIN: ${GOBIN} -> /go/versions/${VERSION}/src/bin" || safe_exit "Failed to create GOBIN symlink"

[ -L "${GOPATH}" ] || ln -s "/go/versions/${VERSION}" "${GOPATH}"
[ -L "${GOPATH}" ] && echo "Configure GOPATH: ${GOPATH} -> /go/versions/${VERSION}" || safe_exit "Failed to create GOPATH symlink"

set_env_vars() {
    local target_file="${1}"
    declare -A env_vars=(
        ["GOOS"]=$GOOS
        ["GOARCH"]=$GOARCH
        ["GOPATH"]=$GOPATH
        ["GOROOT"]=$GOROOT
        ["GOBIN"]=$GOBIN
    )
    echo "Patching file: ${target_file}"

    for var in "${!env_vars[@]}"; do
        if ! grep -qxF "export ${var}=${env_vars[$var]}" "$target_file"; then
            echo "export ${var}=${env_vars[$var]}" >> "$target_file" || safe_exit "Failed to set ${var} in $target_file"
            echo "Set ${var} in $target_file to ${env_vars[$var]}"
        fi
    done

    if ! grep -qxF "export PATH=\$PATH:${GOBIN}" "$target_file"; then
        echo "export PATH=\$PATH:${GOBIN}" >> "$target_file" || safe_exit "Failed to append PATH in $target_file"
        echo "Appended PATH in $target_file"
    fi

    echo "Done patching file: ${target_file}"
}

set_env_vars "/etc/profile"

for file in /home/*/.bashrc; do
  echo "Modifying: $file"
  mv "$file" "$file.bak"
  cp "$file.bak" "$file"
  set_env_vars "${file}"
done

export PATH=$PATH:$GOBIN

GO_VERSION_OUTPUT=$(GOROOT="/go/versions/${VERSION}/src" GOOS="${GOOS}" GOARCH="${GOARCH}" "/go/versions/${VERSION}/src/bin/go" version)

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
  GOROOT="/go/versions/${VERSION}/src" GOOS="${GOOS}" GOARCH="${GOARCH}" "/go/versions/${VERSION}/src/bin/go" install "${packages[$pkg]}@latest"
  [ -f "/go/versions/${VERSION}/src/bin/${pkg}" ] && echo "Installed ${pkg}" || safe_exit "Failed to install ${pkg}"
done

echo "Completed installing Go ${VERSION} for ${GOOS}-${GOARCH}. You will need to parse your .bashrc file now manually: "
echo 
echo "  source ~/.bashrc"
echo 
