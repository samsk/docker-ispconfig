#!/usr/bin/env bash

output=/var/backup/1st-backup-complete.log

# Copy path into /data_tmp when it exists.
# Args: path to back up
backup_path() {
    local path="$1"
    if [ -e "$path" ]; then
        cp -r --parents "$path" /data_tmp/
        echo "$path backed up 1st time" >> "$output"
    else
        echo "$path skipped (missing)" >> "$output"
    fi
}

if [ ! -f "$output" ]
then
    mkdir -p /data_tmp/
    echo "Waiting for 30 sec to ensure install is completed before doing the backup"
    sleep 30
    backup_path /var/lib/amavis/
    backup_path /etc/amavis/
    backup_path /etc/letsencrypt/
    backup_path /etc/apache2/sites-available/
    backup_path /etc/apache2/sites-enabled/
    backup_path /usr/local/ispconfig/
    backup_path /etc/cron.d/
    backup_path /etc/bind/
    backup_path /var/vmail/
    backup_path /var/www/
    backup_path /etc/pure-ftpd/
    backup_path /etc/default/postgrey
    backup_path /etc/systemd/
    dt=$(date '+%d/%m/%Y %H:%M:%S');
    echo "1st Backup Completed $dt" >> "$output"
    echo "1st Backup Completed $dt"
else
    echo "Backup log File found. No backup required, change to Persist Data"
fi
