#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

cleanup_igo() {
    [ -f "${GODIR}/installer.lock" ] && rm -rf "${GODIR}/installer.lock" || echo "Thank you for using igo."
}

cleanup_bgo() {
    [ -f "${GODIR}/backup.lock" ] && rm -rf "${GODIR}/backup.lock" || echo "Thank you for using bgo."
}

cleanup_rgo() {
    [ -f "${GODIR}/uninstaller.lock" ] && rm -rf "${GODIR}/uninstaller.lock" || echo "Thank you for using rgo."
}

safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo "${msg}"
  exit 1
}

igo_usage() {
  local msg="${1:-"No task to perform."}"
  echo "Fatal Error: ${msg}"
  echo "Usage: "
  echo "       $0 VERSION GOOS GOARCH"
  echo
  echo "  $(basename "$0") 1.21.0                      # Linux amd64"
  echo "  $(basename "$0") 1.21.0 darwin amd64         # MacOS amd64"
  echo "  $(basename "$0") 1.21.0 windows              # Windows amd64"
  echo "  $(basename "$0") 1.21.0 windows amd64        # Windows amd64"
  echo
  echo " (!) at least 1 argument is required, which is the GO VERSION argument"
  echo " (!) if only 2 arguments are provided, then the 2nd argument will be assigned to to GOOS variable"
  echo " (!) if all 3 arguments are provided, GO VERSION, GOOS, and GOARCH will be defined in that order"
  echo
  exit 1
}

rgo_usage(){
  local msg="${1:-"BLANK"}"
  [ "${msg}"  != "BLANK" ] && echo "Fatal Error: ${msg}"
  echo "Usage:"
  echo "   $(basename "$0") help               - Show this help message"
  echo "   $(basename "$0") list               - Show installed versions of Go that can be uninstalled"
  echo "   $(basename "$0") <version>          - Remove the specified Go version"
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

source_shell_config() {
  current_shell=$(basename "$SHELL")

  case "$current_shell" in
    bash)
      if [ -f "${HOME}/.bashrc" ]; then
        exec "$SHELL"
      else
        echo "${HOME}/.bashrc not found."
      fi
      ;;
    zsh)
      if [ -f "${HOME}/.zshrc" ]; then
        exec "$SHELL"
      else
        echo "${HOME}/.zshrc not found."
      fi
      ;;
    *)
      echo "Unsupported shell: ${current_shell}."
      ;;
  esac
}

download_script() {
  local src="$1"
  local pkg="$2"
  local file="$3"

  if [ ! -f "${pkg}" ] || [ ! -L "${pkg}" ]; then
    if [ -f "${GODIR}/install-go/${file}" ]; then
      ln -sf "${GODIR}/install-go/${file}" "${pkg}"
    else
      wget --https-only --secure-protocol=auto --no-cache -O "$pkg" "$src" < /dev/null > /dev/null 2>&1 || echo "Downloading ${src}: FAILED, using local if available."
    fi
  else
    echo "Already have $(basename "${pkg}") installed at ${pkg}!"
  fi
}

# Usage: create_backup backup_dir
create_backup() {
    local directory_to_backup="${1}"
    local tar_igo
    local tar_projects
    local duration

    [ ! -d "${directory_to_backup}" ] && safe_exit "No such directory to backup"
    [ -f "${GODIR}/backup.lock" ] && safe_exit "Backup already running"
    date > "${GODIR}/backup.lock"

    printf '[PROJECTS] '
    tar_projects="backup.igo.$(date +%Y.%m.%d).projects.$(hostname).tar.gz"
    SECONDS=0
    tar -czf "${GODIR}/backups/${tar_projects}" "${GODIR}/projects" < /dev/null > /dev/null 2>&1
    duration=$SECONDS
    { [ -f "${GODIR}/backups/${tar_projects}" ] && echo "Backup created: ${GODIR}/backups/${tar_projects} (Completed in ${duration} seconds)"; } || safe_exit "Failed to capture archive of ${directory_to_backup}/${tar_projects}"

    printf '[GOLANG] '
    tar_igo="backup.igo.$(date +%Y.%m.%d).golangs.$(hostname).tar.gz"
    SECONDS=0
    tar -czf "${GODIR}/backups/${tar_igo}" --exclude="${GODIR}/manifests" \
                                           --exclude="${GODIR}/root" \
                                           --exclude="${GODIR}/path" \
                                           --exclude="${GODIR}/bin" \
                                           --exclude="${GODIR}/backups" \
                                           --exclude "${GODIR}/land" \
                                           --exclude="${GODIR}/install-dir" \
                                           --exclude="${GODIR}/projects" \
                                           "${directory_to_backup}" < /dev/null > /dev/null 2>&1
    duration=$SECONDS
    { [ -f "${GODIR}/backups/${tar_igo}" ] && echo "Backup created: ${GODIR}/backups/${tar_igo} (Completed in ${duration} seconds)"; } || safe_exit "Failed to capture archive of ${GODIR}/backups/${tar_igo}"

}

# Usage: deduplicate_backup new_backup backup_dir
deduplicate_backup() {
    local new_backup="$1"
    local backup_dir="$2"
    local hostname=$(hostname)
    local new_hostname_suffix="${hostname}."
    local new_date=${new_backup#*$new_hostname_suffix}  # Remove prefix up to hostname.
    new_date=${new_date%%.*.tar.gz}  # Remove suffix from date.
    local new_checksum=$(sha256sum "$new_backup" | awk '{print $1}')
    local last_matching_backup=""

    for backup in $(ls -t "$backup_dir"/*.tar.gz); do
        local existing_hostname_suffix="${hostname}."
        local existing_date=${backup#*$existing_hostname_suffix}  # Remove prefix up to hostname.
        existing_date=${existing_date%%.*.tar.gz}  # Remove suffix from date.

        [ "$existing_date" == "$new_date" ] && continue  # Skip if the date matches the new backup

        local existing_checksum=$(sha256sum "$backup" | awk '{print $1}')

        if [ "$existing_checksum" == "$new_checksum" ]; then
            last_matching_backup="$backup"
            break
        fi
    done

    if [ -n "$last_matching_backup" ]; then
        echo "Found a matching backup: $last_matching_backup"
        rm "$new_backup"
        [ ! -L "${new_backup}" ] && ln -s "$last_matching_backup" "$new_backup" || safe_exit "Bailing due to ${new_backup} already existing as a symlink."
        [ -L "${new_backup}" ] && echo "Created symlink to duplicate backup: ${new_backup}"
    fi
}

list_versions() {
  [ ! -d "${GODIR}/versions" ] && safe_exit "No Go installed. Use igo to install a version of Go."
  echo "Installed Go versions:"
  for dir in "${GODIR}/versions"/*; do
    if [[ -d "${dir}" ]]; then
      version=$(basename "${dir}")
      local current_version
      [ -f "${GODIR}/version" ] && current_version=$(cat "${GODIR}/version")
      VERSION="$(echo -e "${version}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ "${VERSION}" == "" ] && continue
      [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
      if [ -f "${GODIR}/version" ] && [ "${version}" == "${current_version}" ]; then
        echo "- ${version} * Activated!"
      else
        echo "- ${version}"
      fi
    fi
  done
  echo
  echo "Switch versions by using: sgo VERSION"
  echo
}

list_versions_quiet() {
  [ ! -d "${GODIR}/versions" ] && safe_exit "No Go installed. Use igo to install a version of Go."
  echo
  for dir in "${GODIR}/versions"/*; do
    if [[ -d "${dir}" ]]; then
      version=$(basename "${dir}")
      local current_version
      [ -f "${GODIR}/version" ] && current_version=$(cat "${GODIR}/version")
      VERSION="$(echo -e "${version}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ "${VERSION}" == "" ] && continue
      [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
      if [ -f "${GODIR}/version" ] && [ "${version}" == "${current_version}" ]; then
        echo "- ${version} * Activated!"
      else
        echo "- ${version}"
      fi
    fi
  done
}

switch_version() {
  target_version="$1"

  VERSION="$(echo -e "${target_version}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ "${VERSION}" == "" ] && safe_exit "Invalid VERSION provided."
  [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && safe_exit "Invalid version format"

  if [[ ! -d "${GODIR}/versions/${target_version}" ]]; then
      echo "Error: Version ${target_version} not installed."
      exit 1
  fi
  local current_version=""
  [ -f "${GODIR}/version" ] && current_version=$(cat "${GODIR}/version")
  if [ -f "${GODIR}/version" ] && [ "${current_version}" == "" ]; then
    safe_exit "No ${GODIR}/version file to switch out. Please use igo first."
  fi

  # Create symlink for GOROOT
  rm -rf "${GOROOT}"
  rm -rf "${GOBIN}"
  rm -rf "${GOPATH}"

  ln -s "${GODIR}/versions/${target_version}/go" "${GODIR}/root"
  ln -s "${GODIR}/versions/${target_version}/go/bin" "${GODIR}/bin"
  ln -s "${GODIR}/versions/${target_version}" "${GODIR}/path"

  echo "Updated symlinks from \"${GODIR}/versions/${current_version}\" to \"${GODIR}/versions/${target_version}\"."

  rm -f "${GODIR}/version"
  echo "${target_version}" > "${GODIR}/version"

  GOROOT="${GODIR}/versions/${target_version}/go" "${GODIR}/bin/go" version
}

validate_counter() {
  local counter="$1"
  if [[ ! "$counter" =~ ^[\d]{1,64}$ ]]; then
    echo "Invalid counter value: $counter" >&2
    return 1
  fi
  return 0
}

export COUNTER_FILE="${GODIR}/.db.counter.last_backup"

get_counter() {
  local counter
  counter=$(<"$COUNTER_FILE")
  validate_counter "$counter" || exit 1
  echo "$counter"
}

counter_plus() {
  local counter
  counter=$(get_counter)
  counter=$(( counter + 1 ))
  echo "$counter" > "$COUNTER_FILE"
}

counter_minus() {
  local counter
  counter=$(get_counter)
  if [ "$counter" -gt 0 ]; then
    counter=$(( counter - 1 ))
    echo "$counter" > "$COUNTER_FILE"
  fi
}

ensure_version_installed() {
  target_version="$1"
  printf "Ensuring %s is installed on your system...", target_version
  [[ ! -d "${GODIR}/versions/${target_version}" ]] && safe_exit "Error: Version ${target_version} not installed."
  echo "PASS"
}

remove_sticky_bits() {
  target_version="$1"
  printf "Removing all sticky bits within %s...", target_version
  chmod -R a-s "${GODIR}/versions/${target_version}"
  echo "DONE"
}

remove_immutable_attribute() {
  target_version="$1"
  printf "Removing immutable attributes within %s...", target_version
  chattr -R -i "${GODIR}/versions/${target_version}" || echo "Warning: chattr failed, please ensure you have the required permissions."
  echo "DONE"
}

check_mounted_directory() {
  target_version="$1"
  printf "Ensuring that %s is not a mounted directory...", target_version
  mountpoint -q "${GODIR}/versions/${target_version}" && safe_exit "Error: ${GODIR}/versions/${target_version} is a mounted directory."
  echo "PASS"
}

remove_symlinks() {
  printf "Removing symlinks for %s...", GODIR
  [ -L "${GODIR}/root" ] && rm -rf "${GODIR}/root"
  [ -L "${GODIR}/bin" ] && rm -rf "${GODIR:?}/bin"
  [ -L "${GODIR}/path" ] && rm -rf "${GODIR}/path"
  echo "DONE"
}

remove_version() {
  target_version="$1"
  echo "Uninstalling Go ${target_version} from ${GODIR}."
  ensure_version_installed "${target_version}"
  check_mounted_directory "${target_version}"

  remove_sticky_bits "${target_version}"
  remove_immutable_attribute "${target_version}"

  if [ -f "${GODIR}/version" ]; then
    current_version=$(cat "${GODIR}/version")
    if [ "${current_version}" == "${target_version}" ]; then
      remove_symlinks
      rm -f "${GODIR}/version"
    fi
  fi

  find "${GODIR}/versions/${target_version}" -type d -not -perm -u=w -exec chmod u+w {} \;
  rm -rf "${GODIR}/versions/${target_version}" || safe_exit "Failed to uninstall Go ${target_version}"

  echo "Removed Go version ${target_version}."

  if [ ! -L "${GODIR}/root" ]; then
    echo "   ∟ FYI: You do not have any version of Go active on your system. Please activate a new version by using sgo..."
    sh -c "${GODIR}/scripts/sgo list" || safe_exit "Unable to find sgo on your system"
  fi
}
