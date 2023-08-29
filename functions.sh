#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

cleanup_igo() {
    [ -f "${GODIR}/installer.lock" ] && rm -rf "${GODIR}/installer.lock" || echo "Thank you for using igo."
}

cleanup_bgo() {
    [ -f "${GODIR}/backup.lock" ] && rm -rf "${GODIR}/backup.lock" || echo "Thank you for using bgo."
}

safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo "${msg}"
  exit 1
}

igo_usage() {
  echo "Fatal Error: Missing arguments called VERSION GOOS and GOARCH."
  echo "Usage: "
  echo "       $0 VERSION GOOS GOARCH"
  echo
  echo "  $0 1.21.0                      # Linux amd64"
  echo "  $0 1.21.0 darwin amd64         # MacOS amd64"
  echo "  $0 1.21.0 windows              # Windows amd64"
  echo "  $0 1.21.0 windows amd64        # Windows amd64"
  echo
  echo " (!) at least 1 argument is required, which is the GO VERSION argument"
  echo " (!) if only 2 arguments are provided, then the 2nd argument will be assigned to to GOOS variable"
  echo " (!) if all 3 arguments are provided, GO VERSION, GOOS, and GOARCH will be defined in that order"
  echo
  exit 1
}

validate_version() {
  local version="${1}"
  [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && safe_exit "Invalid version format"
}

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

source_shell_config() {
  current_shell=$(basename "$SHELL")

  case "$current_shell" in
    bash)
      if [ -f "${HOME}/.bashrc" ]; then
        set +u
        source "${HOME}/.bashrc"
        set -u
        echo "Sourced ${HOME}/.bashrc."
      else
        echo "${HOME}/.bashrc not found."
      fi
      ;;
    zsh)
      if [ -f "${HOME}/.zshrc" ]; then
        set +u
        source "${HOME}/.zshrc"
        set -u
        echo "Sourced ${HOME}/.zshrc."
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
    [ ! -d "${directory_to_backup}" ] && safe_exit "No such directory to backup"
    [ -f "${GODIR}/backup.lock" ] && safe_exit "Backup already running"
    date > "${GODIR}/backup.lock"
    
    
    
    local tar_projects
    tar_projects="backup.igo.projects.$(hostname).$(date +%Y.%m.%d).tar.gz"
    SECONDS=0
    tar -czf "${GODIR}/backups/${tar_projects}" "${GODIR}/projects" < /dev/null > /dev/null 2>&1
    local duration=$SECONDS
    { [ -f "${GODIR}/backups/${tar_projects}" ] && echo "Backup created: ${dir}/${tar_projects} (Completed in ${duration} seconds)"; } || safe_exit "Failed to capture archive of ${dir}/${tar_projects}"

    local tar_igo
    tar_igo="backup.igo.installed-golang.$(hostname).$(date +%Y.%m.%d).tar.gz"
    SECONDS=0
    tar -czf "${GODIR}/backups/${tar_igo}" --exclude="${GODIR}/manifests" \
                                           --exclude="${GODIR}/root" \
                                           --exclude="${GODIR}/path" \
                                           --exclude="${GODIR}/bin" \
                                           --exclude="${GODIR}/backups" \
                                           --exclude "${GODIR}/land" \
                                           --exclude="${GODIR}/install-dir" \
                                           --exclude="${GODIR}/versions" \
                                           --exclude="${GODIR}/version" \
                                           --exclude="${GODIR}/projects" \
                                           "${directory_to_backup}" < /dev/null > /dev/null 2>&1
    local duration=$SECONDS
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
  echo "Installed Go versions:"
  for dir in "${GODIR}"/*; do
    if [[ -d "${dir}" ]]; then
      version=$(basename "${dir}")
      ! validate_version "${version}" || continue
      echo "- ${version} # Execute this: $0 ${version}"
    fi
  done
  echo
}

switch_version() {
  target_version="$1"

  validate_version "${target_version}" || safe_exit "Invalid version format (eg 1.21.0)"

  if [[ ! -d "${GO_DIR}/versions/${target_version}" ]]; then
      echo "Error: Version ${target_version} not installed."
      exit 1
  fi

  current_version=$(readlink "${GODIR}/root" | awk -F'/' '{print $NF}')

  ln -sf "${GODIR}/versions/${target_version}/go" "${GODIR}/root"
  ln -sf "${GODIR}/versions/${target_version}/go/bin" "${GODIR}/bin"
  ln -sf "${GODIR}/versions/${target_version}" "${GODIR}/path"

  echo "Updated symlinks from \"${GODIR}/versions/${current_version}\" to \"${GODIR}/versions/${target_version}\"."

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

get_counter() {
  local counter
  counter=$(<"$COUNTER_FILE")  # Read the first line from the file into the variable
  validate_counter "$counter" || exit 1  # Validate the counter
  echo "$counter"  # Output the counter
}

counter_plus() {
  local counter
  counter=$(get_counter)  # Retrieve the current counter value
  counter=$(( counter + 1 ))  # Increment
  echo "$counter" > "$COUNTER_FILE"  # Save back to the file
}

counter_minus() {
  local counter
  counter=$(get_counter)  # Retrieve the current counter value
  if [ "$counter" -gt 0 ]; then  # Ensure the counter never goes negative
    counter=$(( counter - 1 ))  # Decrement
    echo "$counter" > "$COUNTER_FILE"  # Save back to the file
  fi
}

