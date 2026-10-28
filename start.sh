#!/bin/bash

# restore dir tree
for i in /etc/dirtree/*.tree;
do
   [ -e "$i" ] && bash "$i";
done;

set -a;
source /etc/environment.ispconfig || exit 1

echo $(grep $(hostname) /etc/hosts | cut -f1) localhost >> /etc/hosts

envsubst < /root/autoinstall.ini > /root/ispconfig3_install/install/autoinstall.ini

echo $isp_hostname > /etc/mailname

# additional start scripts
[ -d /etc/start.d ] && run-parts --regex ".*\.sh" /etc/start.d

cd /root/ispconfig3_install/install/

if [ -f /usr/local/ispconfig/interface/lib/config.inc.php ];
then
        # Fixed: Table already exists
        rm /root/ispconfig3_install/install/sql/incremental/upd_dev_collection.sql
	/wait-for-it.sh $isp_mysql_hostname:$isp_mysql_port -- php -q update.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
else
	/wait-for-it.sh $isp_mysql_hostname:$isp_mysql_port -- php -q install.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
fi

# Fix from amavis ownerchip that prevents amavis to start
chown -R amavis: /var/lib/amavis/

#sed -i "s/^hosts .*$/hosts = $isp_mysql_hostname/g" /etc/postfix/mysql-virtual_outgoing_bcc.cf
sed -i "s/^myhostname = .*$/myhostname = $isp_hostname/g" /etc/postfix/main.cf
echo message_size_limit=52428800 >> /etc/postfix/main.cf
sed -i "s/^inet_protocols = .*$/inet_protocols = $isp_postfix_protocols/g" /etc/postfix/main.cf
sed -i "s/, check_policy_service unix:private\/quota-status$//g" /etc/postfix/main.cf

#echo "UPDATE mysql.user SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
#echo "UPDATE mysql.db SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
#echo "FLUSH PRIVILEGES;" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password

# Bugfix ISPconfig mysql error
echo "ALTER TABLE ${isp_mysql_master_database}.sys_user MODIFY passwort VARCHAR(140);"  | mysql -u root -h$isp_mysql_hostname -P$isp_mysql_port -p$isp_mysql_root_password
echo "FLUSH PRIVILEGES;" | mysql -u root -h$isp_mysql_hostname -P$isp_mysql_port -p$isp_mysql_root_password

# configure phpmyadmin
envsubst < /root/phpmyadmin.ini > /etc/phpmyadmin/config.inc.php

rm -rf /var/run/saslauthd
ln -sfn /var/spool/postfix/var/run/saslauthd /var/run/saslauthd

screenfetch

# Enable or disable a list of systemd units.
# Args: enable_flag (y/n) followed by unit names.
configure_service() {
   local enable="$1"
   shift

   for i in "$@";
   do
      if [ "$enable" = "y" ];
      then
           systemctl enable "$i" 2>/dev/null || true;
           systemctl start "$i" 2>/dev/null || true;
      else
           systemctl disable "$i" 2>/dev/null || true;
           systemctl stop "$i" 2>/dev/null || true;
      fi;
   done;
}

configure_service "$isp_enable_mail" clamav-daemon.service amavis.service clamav-freshclam.service \
   dovecot.service

configure_service "$isp_enable_dns" named

configure_service "$isp_enable_apache" apache2
configure_service "$isp_enable_nginx" nginx
if [ "$isp_enable_apache" = "y" ] || [ "$isp_enable_nginx" = "y" ];
then
  systemctl enable "php${isp_php_version}-fpm"
  systemctl start "php${isp_php_version}-fpm"
fi

if [ "$isp_enable_jailkit" = "y" ];
then
  systemctl start ssh
fi

systemctl restart cron
systemctl start postgrey
systemctl start pure-ftpd

# Valkey opt-in (default n)
if systemctl list-unit-files valkey-server.service >/dev/null 2>&1; then
  configure_service "$isp_enable_redis" valkey-server
elif systemctl list-unit-files valkey.service >/dev/null 2>&1; then
  configure_service "$isp_enable_redis" valkey
fi

# fix rncd erro
chown root:bind /etc/bind/rndc.key

if [ -f "/var/backup/1st-backup-complete.log" ];
then
    echo "1st Backup file exists. Nothing to do here"
else
    /do-1st-backup.sh &
fi

unset isp_mysql_root_password
unset isp_mysql_ispconfig_password
unset isp_mysql_master_root_password
unset isp_admin_password
unset isp_mysql_database

exit 0;
