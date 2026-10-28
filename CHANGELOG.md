## v3.3.2p1-1

- UPDATE: ISPConfig to 3.3.2p1 (official tarball)
- CHANGE: stop overlaying 3.2 install.php/update.php; use stock 3.3 installer
- CHANGE: ISPConfig install/update via php8.3 CLI
- FIX: empty VOLUME dir no longer blocks install.php; quote isp_* env values
- FIX: grant ispconfig@'%' (MariaDB skip_name_resolve); map y/n → yes/no for update
- KEEP: Ubuntu Noble, Dovecot, multi-PHP, Valkey opt-in, systemd

## v3.2.12-2

- UPDATE: Baseimage to Ubuntu Noble (24.04 LTS)
- ADD: PHP 8.4 and 8.5 (multi-PHP: 7.4 8.1 8.2 8.3 8.4 8.5)
- ADD: Valkey + php-redis (optional; `isp_enable_redis`, default n)
- CHANGE: Courier → Dovecot (apt; ISPConfig preferred; Courier gone from Noble)
- FIX: Restore filesystem `quota` / `quotatool` packages
- FIX: Replace `netcat` with `netcat-openbsd`; drop `gamin`

## v3.2.12-1

- UPDATE: Baseimage to Ubuntu Jammy
- UPDATE: ISPConfig to 3.2.12p1 (clone from AVENTER-UG/ispconfig3 mirror)
- MERGE: upstream AVENTER-UG (postgrey, fail2ban, client_checks, Makefile/SBOM)
- KEEP: systemd PID 1, pure-ftpd, multi-PHP (fork)
