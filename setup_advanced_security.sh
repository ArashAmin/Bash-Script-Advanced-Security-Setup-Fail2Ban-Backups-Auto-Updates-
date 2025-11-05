#!/bin/bash

# Advanced Security Setup Script for Ubuntu Server
# Installs Fail2Ban, configures jails for SSH/Apache, sets up rsync backups with cron,
# and enables unattended upgrades. Run with sudo.

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Run this script with sudo."
   exit 1
fi

echo "Starting advanced security setup..."

# Step 1: Install and enable Fail2Ban
apt update -y
apt install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban

# Step 2: Configure Fail2Ban jails
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache2/*error.log
EOF

systemctl restart fail2ban
fail2ban-client status sshd  # Quick status check

# Step 3: Setup rsync backups and cron
apt install rsync -y
mkdir -p /backup/home_backup /backup/web_backup

# Create backup script
cat > /usr/local/bin/daily_backup.sh << EOF
#!/bin/bash
rsync -avz /home/arri/ /backup/home_backup/
rsync -avz /var/www/html/ /backup/web_backup/
echo "Backup completed: $(date)" >> /var/log/backup.log
EOF

chmod +x /usr/local/bin/daily_backup.sh

# Add to cron (daily at 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/daily_backup.sh") | crontab -

# Step 4: Enable unattended upgrades
apt install unattended-upgrades -y
dpkg-reconfigure unattended-upgrades -f noninteractive

# Edit config for security and updates
sed -i 's|//\t"${distro_id}:${distro_codename}-updates";|"\${distro_id}:\${distro_codename}-updates";|' /etc/apt/apt.conf.d/50unattended-upgrades
sed -i 's|//\t"${distro_id}:${distro_codename}-security";|"\${distro_id}:\${distro_codename}-security";|' /etc/apt/apt.conf.d/50unattended-upgrades

unattended-upgrades --dry-run  # Test run

# Step 5: Log monitoring example
tail -n 3 /var/log/auth.log  # Show recent auth logs

echo "Advanced security setup completed!"
echo "Fail2Ban: Active (check with 'fail2ban-client status sshd')"
echo "Backups: Daily at 3 AM (logs in /var/log/backup.log)"
echo "Unattended upgrades: Enabled for security and updates"