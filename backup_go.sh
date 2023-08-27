#!/bin/bash

######################################################################
# Script Name: backup_go.sh
# Description: This script is designed to create backups of the /go directory
#              and store them in /go/backups. It also deduplicates these backups
#              to save storage space by creating symlinks to identical backups.
#
# Organization:
# 1. Configuration and Environment Setup
#    - Setting up script behavior on errors and debug mode.
#    - Cleanup trap.
# 2. Functions
#    - cleanup: Cleans up any lingering lock files.
#    - safe_exit: Safely exits the script, outputting an error message.
#    - deduplicate_backup: Checks for duplicate backups, creates symlinks if found.
#    - create_backup: Creates the backup tarball, calls deduplication.
#
# Functions:
# - cleanup(): Deletes the lock file on script exit or interruption.
# - safe_exit(message): Exits the script with a custom error message.
# - deduplicate_backup(new_backup, backup_dir): Checks for duplicates of new_backup
#     in backup_dir and replaces them with symlinks to save storage.
#     Also ensures that backups are unique per hostname.
# - create_backup(backup_dir): Creates a tarball of the /go directory in backup_dir,
#     excluding certain subdirectories. Calls deduplicate_backup.
#
# Developer Notes:
# - The script must be run as root.
# - Ensure that the /go directory exists and is the correct target for backup.
# - The script uses a lock file mechanism to ensure that only one instance runs at a time.
# - All backups are stored in /go/backups. This directory will be created if it doesn't exist.
# - The deduplication logic is based on SHA-256 checksums and hostnames.
# - SECONDS variable is a built-in Bash variable to calculate time duration.
#
######################################################################

set -e
[ "${DEBUG}" == "1" ] && set -x
set -u
set -o pipefail
set -v

# Usage: cleanup
cleanup() {
	[ -f /go/backupgo.lock ] && rm -rf /go/backupgo.lock || echo "Thank you for using backupgo."
}

trap cleanup EXIT INT TERM

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# Usage: safe_exit message
safe_exit() {
	local msg="${1}"
	echo "${msg}"
	exit 1
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

    if [ ! -z "$last_matching_backup" ]; then
        echo "Found a matching backup: $last_matching_backup"
        rm "$new_backup"
        [ ! -L "${new_backup}" ] && ln -s "$last_matching_backup" "$new_backup" || safe_exit "Bailing due to ${new_backup} already existing as a symlink."
        [ -L "${new_backup}" ] && echo "Created symlink to duplicate backup: ${new_backup}"
    fi
}

if [ ! -d /go ]; then
  echo "You must have Go installed at /go via the installgo package."
  exit 1
fi

[ -f /go/backupgo.lock ] && safe_exit "Already running..."

DIR="/go/backups"

[ ! -d $DIR ] && mkdir -p $DIR
[ -d $DIR ] && echo "Checked directory: ${DIR}" || safe_exit "Failed to create directory ${DIR}"

# Usage: create_backup backup_dir
create_backup() {
    local dir="${1}"

    echo "$(date)" > /go/backupgo.lock

    local archive="go.$(hostname).$(date +%Y.%m.%d).tar.gz"
    echo "Creating backup: ${dir}/${archive}"
    SECONDS=0
    tar -czf "${dir}/${archive}" --exclude="${dir}" --exclude='/go/root' --exclude='/go/path' --exclude='/go/bin' /go < /dev/null > /dev/null 2>&1
    local duration=$SECONDS
    [ -f "${dir}/${archive}" ] && echo "Backup created: ${dir}/${archive} (Completed in ${duration} seconds)" || safe_exit "Failed to capture archive of ${dir}/${archive}"

    deduplicate_backup "${dir}/${archive}" "${dir}"
}

create_backup "${DIR}"
