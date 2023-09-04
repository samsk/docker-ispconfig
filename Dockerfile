FROM ubuntu:jammy

MAINTAINER Andreas Peters <support@aventer.biz> version: 0.2


ENV isp_mysql_hostname localhost
ENV isp_mysql_port 3306
ENV isp_mysql_root_user root
ENV isp_mysql_root_password default
ENV isp_mysql_database dbispconfig
ENV isp_mysql_ispconfig_password default
ENV isp_mysql_master_root_user root
ENV isp_mysql_master_root_password default
ENV isp_mysql_master_hostname localhost
ENV isp_mysql_master_port 3306
ENV isp_mysql_master_user root
ENV isp_mysql_master_database dbispconfig
ENV isp_admin_password default
ENV isp_enable_webserver y
ENV isp_enable_mail n
ENV isp_enable_jailkit n
ENV isp_enable_ftp n
ENV isp_enable_dns y
ENV isp_enable_apache y
ENV isp_enable_nginx y
ENV isp_enable_firewall y
ENV isp_enable_webinterface y
ENV isp_enable_multiserver n
ENV isp_hostname localhost
ENV isp_cert_hostname localhost
ENV isp_use_ssl y
ENV isp_change_mail_server y
ENV isp_change_web_server y
ENV isp_change_dns_server y
ENV isp_change_xmpp_server y
ENV isp_change_firewall_server y
ENV isp_change_vserver_server y
ENV isp_change_db_server y
ENV isp_php_version 7.4
ENV isp_php_versions_available 7.4 8.1 8.2 8.3

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && \
   apt-get -y upgrade && \
   apt-get -y remove openbsd-inetd update-inetd tcpd && \
   apt-get -y install quota quotatool software-properties-common quota mysql-client wget \
     curl vim rsyslog rsyslog-relp logrotate automysqlbackup screenfetch apt-utils gettext-base git \
     systemd supervisor libpam-script libpam-abl iputils-ping xinetd rinetd netcat \
     ssh openssh-server rsync openssh-sftp-server gesftpserver etckeeper && \
   add-apt-repository ppa:ondrej/php && \
   apt-get -y update && \
   apt-get -y upgrade && \
   apt-get -y autoremove

# Install Postfix, Dovecot, rkhunter, binutils
RUN apt-get install -y courier-authdaemon courier-authlib courier-authlib-userdb
# workaround courier install bug
RUN touch /usr/share/man/man5/maildir.courier.5.gz  \
    && touch /usr/share/man/man8/deliverquota.courier.8.gz \
    && touch /usr/share/man/man1/maildirmake.courier.1.gz \
    && touch /usr/share/man/man7/maildirquota.courier.7.gz \
    && touch /usr/share/man/man1/makedat.courier.1.gz \
    && ls -l /usr/share/man/man7/ \
    && apt-get -y install courier-base

# Install PhpMyAdmin
RUN echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections && \
      echo 'phpmyadmin phpmyadmin/mysql/admin-pass password pass' | debconf-set-selections && \
      apt-get -y install phpmyadmin
ADD ./etc/phpmyadmin/phpmyadmin.ini /root/phpmyadmin.ini

# Workaround maildrop install bug
RUN touch /usr/share/man/man5/maildir.maildrop.5.gz \
    && touch /usr/share/man/man7/maildirquota.maildrop.7.gz \
    && apt-get install -y maildrop

RUN apt-get -y install postfix mysql-client postfix-mysql postfix-doc openssl getmail6 rkhunter binutils courier-authlib-mysql courier-pop courier-pop courier-imap courier-imap libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql sudo gamin && \
      service postfix stop
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
ADD ./etc/courier/authmysqlrc.ini /root/authmysqlrc.ini

# Install Amavisd-new, SpamAssassin And Clamav
RUN apt-get -y install amavisd-new spamassassin clamav clamav-daemon unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl postgrey && \
      service spamassassin stop && \
      service clamav-daemon stop
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

# Install BIND DNS Server && deactivate ipv6
RUN apt-get -y install bind9 dnsutils haveged && \
      sed -i 's/-u bind/-u bind -4/g' /etc/default/named &&\
      service haveged start && \
      service named stop

# Install Vlogger, Webalizer, and AWStats
RUN apt-get -y install vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl
ADD etc/cron.d/awstats /etc/cron.d/

# Install fail2ban
RUN apt-get -y install pure-ftpd fail2ban && \
      systemctl enable pure-ftpd
ADD ./etc/ssl /etc/ssl
ADD ./etc/pure-ftpd /etc/pure-ftpd
ADD ./etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./etc/fail2ban/filter.d/pureftpd.conf /etc/fail2ban/filter.d/pureftpd.conf
ADD ./etc/fail2ban/filter.d/postfix-sasl.conf /etc/fail2ban/filter.d/postfix-sasl.conf

# Install Apache2, PHP, FCGI, suExec, Pear, And mcrypt
RUN apt-get -y install apache2 apache2-doc apache2-utils libapache2-mod-php incron \
        libapache2-mod-fcgid apache2-suexec-pristine memcached \
        mcrypt imagemagick libruby ;\
        for ver in $isp_php_versions_available; \
        do \
           apt-get install -y --ignore-missing libapache2-mod-php8.3 \
                     php${ver} php${ver}-common php${ver}-gd php${ver}-mysql php${ver}-imap php${ver}-cli \
                     php${ver}-cgi php${ver}-opcache php${ver}-bcmath php${ver}-soap \
                     php${ver}-fpm php${ver}-curl php${ver}-intl php${ver}-pspell php${ver}-sqlite3 \
                     php${ver}-xsl php${ver}-zip php${ver}-mbstring; \
        done; \
        apt-get install -y php-mcrypt php-xmlrpc php-uuid php-yaml php-memcache php-imagick \
          php-apcu php-soap php-pear php-json

ADD ./etc/apache2/conf-available/httpoxy.conf /etc/apache2/conf-available/httpoxy.conf
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf && \
      a2enconf servername && \
      a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers && \
      a2enconf httpoxy && \
      a2dissite 000-default && \
      update-alternatives --set php /usr/bin/php7.4 && \
      a2enmod actions proxy_fcgi alias && \
      service apache2 stop

# Install Let's Encrypt
RUN apt-get -y install python3-certbot-apache

# ISPCONFIG Initialization and Startup Script
ADD ./wait-for-it.sh /wait-for-it.sh
ADD ./autoinstall.ini /root/autoinstall.ini
ADD ./start.sh /start.sh
ADD ./etc/ssh /etc/ssh
ADD ./etc/rsyslog/rsyslog.conf /etc/rsyslog.conf
ADD ./etc/cron.daily/sql_backup.sh /etc/cron.daily/sql_backup.sh
ADD ./etc/systemd /etc/systemd
ADD ./etc/pam.d /etc/pam.d
ADD ./etc/security /etc/security
ADD ./etc/scripts /etc/scripts
ADD ./etc/sudoers.d /etc/sudoers.d

RUN for i in pam_script_acct pam_script_ses_close pam_script_ses_open pam_script_auth; \
       do ln -svf /etc/scripts/$i /usr/share/libpam-script/;done
RUN systemctl enable ispconfig-start.service

ADD ./etc/postfix/master.cf /etc/postfix/master.cf
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

# Install ISPConfig 3
ARG ISPCONFIG_TAG=3.2.11

RUN git clone --branch $ISPCONFIG_TAG --depth 1 https://git.ispconfig.org/ispconfig/ispconfig3.git /root/ispconfig3_install
ADD ./update.php /root/ispconfig3_install/install/update.php
ADD ./install.php /root/ispconfig3_install/install/install.php

RUN grep -R ISPC_APP_VERSION /root/ispconfig3_install

EXPOSE 53 80/tcp 443/tcp 953/tcp 8080/tcp 30000 30001 30002 30003 30004 30005 30006 30007 30008 30009 $isp_mysql_port

#ADD ./bin/systemctl /bin/systemctl
RUN chmod 755 /start.sh && \
      mkdir -p /var/run/sshd \
         /var/log/.abl \
         /var/log/supervisor \
         /var/backup/sql \
         /var/spool/postfix/private \
         /var/lib/php-fpm \
         /home/chroot && \
      touch /var/spool/postfix/private/quota-status && \
      chown postfix:root /var/spool/postfix/private && \
      chown postfix:postfix /var/spool/postfix/private/quota-status && \
      chmod 0660 /var/spool/postfix/private/quota-status && \
      ln -s /dev/urandom /root/.rnd && \
      rm -rf /dev/random && \
      ln -s /dev/urandom /dev/random && \
      chmod 755 /var/log && \
      echo "export TERM=xterm" >> /root/.bashrc && \
      echo "column-statistics=0" >> /etc/mysql/conf.d/mysqldump.cnf && \
      etckeeper init && \
      rm -rf /sbin/init && \
      mkdir -p /var/www/sites /var/log/root && \
      chmod 0700 /var/log/root && \
      ln -sf /root/.bash_history /var/log/root/.bash_history

# save directory tree
RUN mkdir -p /etc/dirtree && \
     find /var/log -type d -printf "mkdir -p %p; chown %U:%G %p; chmod %m %p;\n" >/etc/dirtree/var_log.tree;

## logrotate woradounds
ADD ./etc/logrotate/rsyslog-rotate /usr/lib/rsyslog/rsyslog-rotate 

VOLUME ["/etc"]
VOLUME ["/usr/local/ispconfig"]
VOLUME ["/var/log"]

## Initial Backup
ADD ./do-1st-backup.sh /do-1st-backup.sh
ADD ./init /sbin/init
ADD ./isp-mysql /usr/local/sbin

CMD [ "/sbin/init" ]
