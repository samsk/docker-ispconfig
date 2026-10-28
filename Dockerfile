FROM ubuntu:noble

LABEL maintainer="Andreas Peters <support@aventer.biz>"
LABEL org.opencontainers.image.title="docker-ispconfig"
LABEL org.opencontainers.image.description="This docker image include a whole ISPConfig3 software stack!"
LABEL org.opencontainers.image.vendor="AVENTER UG (haftungsbeschränkt)"
LABEL org.opencontainers.image.source="https://github.com/AVENTER-UG/docker-ispconfig"

ENV isp_mysql_hostname=localhost
ENV isp_mysql_port=3306
ENV isp_mysql_root_user=root
ENV isp_mysql_root_password=default
ENV isp_mysql_database=dbispconfig
ENV isp_mysql_ispconfig_password=default
ENV isp_mysql_master_root_user=root
ENV isp_mysql_master_root_password=default
ENV isp_mysql_master_hostname=localhost
ENV isp_mysql_master_port=3306
ENV isp_mysql_master_user=root
ENV isp_mysql_master_database=dbispconfig
ENV isp_admin_password=default
ENV isp_enable_webserver=y
ENV isp_enable_mail=n
ENV isp_enable_jailkit=n
ENV isp_enable_ftp=n
ENV isp_enable_dns=y
ENV isp_enable_apache=y
ENV isp_enable_nginx=y
ENV isp_enable_firewall=y
ENV isp_enable_webinterface=y
ENV isp_enable_multiserver=n
ENV isp_enable_redis=n
ENV isp_redis_port=6379
ENV isp_hostname=localhost
ENV isp_cert_hostname=localhost
ENV isp_use_ssl=y
# yes/no required by update.php simple_query (y loops forever)
ENV isp_change_mail_server=yes
ENV isp_change_web_server=yes
ENV isp_change_dns_server=yes
ENV isp_change_xmpp_server=yes
ENV isp_change_firewall_server=yes
ENV isp_change_vserver_server=yes
ENV isp_change_db_server=yes
ENV isp_postfix_protocols=ipv4
ENV isp_php_version=8.3
ENV isp_php_versions_available="7.4 8.1 8.2 8.3 8.4 8.5"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
RUN apt-get -y update && \
   apt-get -y upgrade && \
   apt-get -y remove openbsd-inetd tcpd && \
   apt-get -y install quota quotatool software-properties-common mysql-client wget \
     update-inetd \
     curl vim rsyslog rsyslog-relp logrotate automysqlbackup screenfetch apt-utils gettext-base git \
     systemd supervisor libpam-script libpam-abl iputils-ping xinetd rinetd netcat-openbsd \
     ssh openssh-server rsync openssh-sftp-server gesftpserver etckeeper locales && \
   printf 'en_US ISO-8859-1\nen_US.UTF-8 UTF-8\n' >> /etc/locale.gen && locale-gen && \
   add-apt-repository ppa:ondrej/php && \
   apt-get -y update && \
   apt-get -y upgrade && \
   apt-get -y autoremove

# Install PhpMyAdmin
RUN echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections && \
      echo 'phpmyadmin phpmyadmin/mysql/admin-pass password pass' | debconf-set-selections && \
      apt-get -y install phpmyadmin
ADD ./etc/phpmyadmin/phpmyadmin.ini /root/phpmyadmin.ini

# Postfix + Dovecot (ISPConfig mail stack; Courier dropped on Noble)
RUN apt-get -y install postfix mysql-client postfix-mysql postfix-doc openssl getmail6 rkhunter binutils \
        dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd dovecot-managesieved \
        libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql sudo && \
      service postfix stop
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
ADD ./etc/security/limits.conf /etc/security/limits.conf

# Install Amavisd-new, SpamAssassin And Clamav
RUN apt-get -y install amavisd-new spamassassin clamav clamav-daemon unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl postgrey && \
      (service spamd stop || service spamassassin stop || true) && \
      (service clamav-daemon stop || true)
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

# Install BIND DNS Server && deactivate ipv6
RUN apt-get -y install bind9 dnsutils haveged && \
      sed -i 's/-u bind/-u bind -4/g' /etc/default/named &&\
      service haveged start && \
      service named stop

# Install Webalizer and AWStats (vlogger from ISPConfig tree later)
RUN apt-get -y install webalizer awstats geoip-database libclass-dbi-mysql-perl
ADD etc/cron.d/awstats /etc/cron.d/

# Install Jailkit
RUN apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils python3 jailkit

# Install fail2ban and pure-ftpd
RUN apt-get -y install pure-ftpd fail2ban && \
      systemctl enable pure-ftpd
ADD ./etc/ssl /etc/ssl
ADD ./etc/pure-ftpd /etc/pure-ftpd
ADD ./etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./etc/fail2ban/filter.d/* /etc/fail2ban/filter.d/

# Install Apache2, multi-PHP (incl. 8.4/8.5), FCGI, Pear
RUN apt-get -y install apache2 apache2-doc apache2-utils libapache2-mod-php incron \
        libapache2-mod-fcgid apache2-suexec-pristine memcached \
        mcrypt imagemagick libruby ;\
        for ver in $isp_php_versions_available; \
        do \
           apt-get install -y --ignore-missing \
                     libapache2-mod-php${ver} \
                     php${ver} php${ver}-common php${ver}-gd php${ver}-mysql php${ver}-imap php${ver}-cli \
                     php${ver}-cgi php${ver}-opcache php${ver}-bcmath php${ver}-soap \
                     php${ver}-fpm php${ver}-curl php${ver}-intl php${ver}-pspell php${ver}-sqlite3 \
                     php${ver}-xsl php${ver}-zip php${ver}-mbstring php${ver}-redis php${ver}-tidy; \
        done; \
        apt-get install -y php-mcrypt php-xmlrpc php-uuid php-yaml php-memcache php-imagick \
          php-apcu php-soap php-pear php-json php-redis

ADD ./etc/apache2/conf-available/httpoxy.conf /etc/apache2/conf-available/httpoxy.conf
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf && \
      a2enconf servername && \
      a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers && \
      a2enconf httpoxy && \
      a2dissite 000-default && \
      update-alternatives --set php /usr/bin/php8.3 && \
      a2enmod actions proxy_fcgi alias && \
      service apache2 stop

# Valkey (optional daemon; php-redis already installed)
RUN apt-get -y install valkey valkey-tools && \
      systemctl disable valkey-server 2>/dev/null || true; \
      systemctl disable valkey 2>/dev/null || true
ADD ./etc/valkey/valkey.conf /etc/valkey/valkey.conf

# Install Let's Encrypt
RUN apt-get -y install python3-certbot-apache

# UFW firewall
RUN apt-get -y install ufw

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

ADD ./etc/postfix/client_checks /etc/postfix/client_checks
RUN postmap /etc/postfix/client_checks

ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

# Install ISPConfig 3 (official tarball; AVENTER git mirror has no 3.3 tags)
ARG ISPCONFIG_TAG=3.3.2p1
ARG ISPCONFIG_SHA256=b3a2111e997df8e1472933788c2809f038498e97bc00fbd285e18a84a47d4a93

RUN wget -q -O /tmp/ispconfig.tar.gz \
      "https://www.ispconfig.org/downloads/ISPConfig-${ISPCONFIG_TAG}.tar.gz" && \
    echo "${ISPCONFIG_SHA256}  /tmp/ispconfig.tar.gz" | sha256sum -c - && \
    tar xzf /tmp/ispconfig.tar.gz -C /root && \
    rm -f /tmp/ispconfig.tar.gz
# Containers lack CAP_LINUX_IMMUTABLE; skip chattr hardening
RUN python3 -c 'from pathlib import Path; p=Path("/root/ispconfig3_install/install/lib/installer_base.lib.php"); s=p.read_text(); marker="\tpublic function set_immutable($path, $enable = true) {\n"; assert s.count(marker) == 1, "set_immutable marker changed"; p.write_text(s.replace(marker, marker + "\t\tif(is_file(\"/.dockerenv\")) return;\n", 1))'
# Remote MariaDB + skip_name_resolve: grant ispconfig@'%' not @hostname
RUN python3 -c 'from pathlib import Path; p=Path("/root/ispconfig3_install/install/lib/installer_base.lib.php"); s=p.read_text(); old="\t\t} else {\n\t\t\t$from_host = $conf['\''hostname'\''];\n\t\t}"; new="\t\t} else {\n\t\t\t$from_host = is_file('\''/.dockerenv'\'') ? '\''%'\'' : $conf['\''hostname'\''];\n\t\t}"; assert s.count(old) >= 1, "from_host hostname branch not found"; p.write_text(s.replace(old, new, 1))'
# Empty VOLUME /usr/local/ispconfig is a dir; allow first-boot install.php
RUN python3 -c 'from pathlib import Path; p=Path("/root/ispconfig3_install/install/install.php"); s=p.read_text(); old="if(is_dir('\''/usr/local/ispconfig'\'')) {\n\tdie('\''ISPConfig 3 installation found. Please use update.php instead if install.php to update the installation.'\'');\n}"; assert old in s, "already-installed guard not found"; p.write_text(s.replace(old, "if(is_dir('\''/usr/local/ispconfig'\'') && is_file('\''/usr/local/ispconfig/interface/lib/config.inc.php'\'')) {\n\tdie('\''ISPConfig 3 installation found. Please use update.php instead of install.php to update the installation.'\'');\n}", 1))'
RUN install -m 0755 /root/ispconfig3_install/server/scripts/vlogger /usr/sbin/vlogger

RUN grep -R ISPC_APP_VERSION /root/ispconfig3_install | head -20

EXPOSE 53 80/tcp 443/tcp 953/tcp 8080/tcp 30000 30001 30002 30003 30004 30005 30006 30007 30008 30009 $isp_mysql_port $isp_redis_port

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
      echo 'START="yes"' >> /etc/default/saslauthd && \
      (etckeeper init || true) && \
      rm -rf /sbin/init && \
      mkdir -p /var/www/sites /var/log/root && \
      chmod 0700 /var/log/root && \
      ln -sf /root/.bash_history /var/log/root/.bash_history

# save directory tree
RUN mkdir -p /etc/dirtree && \
     find /var/log -type d -printf "mkdir -p %p; chown %U:%G %p; chmod %m %p;\n" >/etc/dirtree/var_log.tree;

## logrotate woradounds
ADD ./etc/logrotate/rsyslog-rotate /usr/lib/rsyslog/rsyslog-rotate

## FIX: Postgrey listening interface
ADD ./etc/default/postgrey /etc/default/postgrey

VOLUME ["/etc"]
VOLUME ["/usr/local/ispconfig"]
VOLUME ["/var/log"]

## Initial Backup
ADD ./do-1st-backup.sh /do-1st-backup.sh
ADD ./init /sbin/init
ADD ./isp-mysql /usr/local/sbin

CMD [ "/sbin/init" ]
