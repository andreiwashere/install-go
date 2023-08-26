#!/bin/bash

set -e

[ "${DEBUG}" == "1" ] && set -x

cleanup() {
	[ -f /go/backupgo.lock ] && rm -rf /go/backupgo.lock || echo "Thank you for using backupgo."
}

trap cleanup EXIT INT TERM

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

safe_exit() {
	local msg="${1}"
	echo "${msg}"
	exit 1
}

if [ ! -d /go ]; then
  echo "You must have Go installed at /go via the installgo package."
  exit 1
fi

[ -f /go/backupgo.lock ] && safe_exit "Already running..."

DIR="/go/backups"

[ ! -d $DIR ] && mkdir -p $DIR
[ -d $DIR ] && echo "Created directory: ${DIR}" || safe_exit "Failed to create directory ${DIR}"

echo "$(date)" > /go/backupgo.lock

ARCHIVE="go.$(hostname).$(date +%Y.%m.%d).tar.gz"

tar -czf "${DIR}/${ARCHIVE}" --exclude="${DIR}" --exclude='/go/root' --exclude='/go/path' --exclude='/go/bin' /go < /dev/null > /dev/null 2>&1
[ -f "${DIR}/${ARCHIVE}" ] && echo "Backup created: ${DIR}/${ARCHIVE}" || safe_exit "Failed to capture archive of ${DIR}/${ARCHIVE}"

