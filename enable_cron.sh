#!/bin/bash

set -e

[ "${DEBUG}" == "1" ] && set -x

TMP_CRONFILE="/root/tmp_crontab"

cleanup() {
    [ -f "${TMP_CRONFILE}" ] && rm -rf "${TMP_CRONFILE}" || echo "Thank you for using ${0}"
}

trap cleanup EXIT INT TERM

safe_exit() {
    local msg="${1}"
    echo "${msg}"
    exit 1
}

calc_retention_days() {
    local root_free_space=$(df / --output=avail | tail -n1)  # in 1K blocks
    local go_dir_size=$(du -s /go | cut -f1)  # in 1K blocks
    local sixty_percent_space=$((root_free_space * 6 / 10))
    local projected_go_size=$((go_dir_size * 117))

    if [ $projected_go_size -lt $sixty_percent_space ]; then
        echo 117
    else
        local safe_factor=$((sixty_percent_space / (3 * go_dir_size)))
        [ $safe_factor -lt 14 ] && echo 14 || echo $safe_factor
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

crontab -l > "${TMP_CRONFILE}" 2>/dev/null || echo "No existing crontab. Creating one..."

sed -i '/backupgo/d' "${TMP_CRONFILE}"

cron_time="${1:-"34 4 * * *"}"

[[ "$cron_time" =~ ^[\*\/0-9,-]+\ [\*\/0-9,-]+\ [\*\/0-9,-]+\ [\*\/0-9,-]+\ [\*\/0-9,-]+$ ]] || safe_exit "Invalid cron time format."

retention_days=$(calc_retention_days)

echo "${cron_time} /usr/bin/backupgo" >> "${TMP_CRONFILE}"
echo "17 1 * * * find /go/backups/*.tar.gz -mtime +${retention_days} -exec rm {} \;" >> "${TMP_CRONFILE}"

[ -f "${TMP_CRONFILE}" ] && crontab "${TMP_CRONFILE}" || safe_exit "Failed to install new crontab."

echo "Crontab for backupgo has been successfully updated."
