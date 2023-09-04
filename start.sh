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

#echo "UPDATE mysql.user SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
#echo "UPDATE mysql.db SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
#echo "FLUSH PRIVILEGES;" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password

# Bugfix ISPconfig mysql error
echo "ALTER TABLE ${isp_mysql_master_database}.sys_user MODIFY passwort VARCHAR(140);"  | mysql -u root -h$isp_mysql_hostname -P$isp_mysql_port -p$isp_mysql_root_password
echo "FLUSH PRIVILEGES;" | mysql -u root -h$isp_mysql_hostname -P$isp_mysql_port -p$isp_mysql_root_password

# Bugfix ISPconfig missing markerline
envsubst < /root/authmysqlrc.ini > /etc/courier/authmysqlrc

# configure phpmyadmin
envsubst < /root/phpmyadmin.ini > /etc/phpmyadmin/config.inc.php

mkdir -p /etc/courier/shared/index
chmod -R 770 /etc/courier/shared

rm -rf /var/run/saslauthd
ln -sfn /var/spool/postfix/var/run/saslauthd /var/run/saslauthd

screenfetch

function configure_service() {
   local enable=shift;

   for i in "$@";
   do
      if [ "$enable" != "${enable~~y}"];
      then
           systemctl enable "$i";
           systemctl start "$i";
      else
           systemctl disable "$i";
           systemctl stop "$i";
      fi;
   done;
}

configure_service "$isp_enable_mail" clamav-daemon.service amavis.service clamav-freshclam.service \
   courier-authdaemon.service courier-imap-ssl.service courier-imap.service courier-pop-ssl.service courier-pop.service \

configure_service "$isp_enable_dns" named

configure_service "$isp_enable_apache$isp_enable_nginx" apache nginx php${isp_php_version}-fpm

# fix rncd erro
chown root:bind /etc/bind/rndc.key
# fix index permission error
chown courier: /etc/courier/shared/index

if [ -f "/var/backup/1st-backup-complete.log" ]; 
then 
    echo "1st Backup file exists. Nothing to do here" 
else 
    /do-1st-backup.sh &
fi

systemctl start pure-ftpd

exit 0;
