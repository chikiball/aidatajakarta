#!/bin/bash
# ═══════════════════════════════════════════════════
# OS-level hardening for Ubuntu home server
# Run ONCE after init-server.sh
#
# Usage: sudo bash harden-os.sh
# ═══════════════════════════════════════════════════
set -euo pipefail

echo ""
echo "═══════════════════════════════════════════"
echo "  🧱 Hardening Ubuntu Server"
echo "═══════════════════════════════════════════"
echo ""

# ─── 1. UFW Firewall ───
echo "1/4  Configuring UFW firewall..."
apt-get install -y ufw > /dev/null 2>&1

ufw default deny incoming
ufw default allow outgoing

# SSH — restrict to local network only (adjust to your subnet)
ufw allow from 192.168.0.0/16 to any port 22 proto tcp comment 'SSH (LAN only)'

# With Cloudflare Tunnel, we need NO inbound web ports.
# All traffic arrives via the outbound tunnel.
# If you ever need direct access for debugging:
#   ufw allow from 192.168.0.0/16 to any port 80 proto tcp comment 'HTTP (LAN debug)'

ufw --force enable
echo "  ✅ UFW enabled (SSH from LAN only, no public ports)"

# ─── 2. Fail2Ban ───
echo "2/4  Installing Fail2Ban..."
apt-get install -y fail2ban > /dev/null 2>&1

cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
banaction = ufw

# ─── SSH brute force protection ───
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 24h
JAIL

systemctl enable fail2ban
systemctl restart fail2ban
echo "  ✅ Fail2Ban active (SSH: 3 attempts → 24h ban)"

# ─── 3. SSH hardening ───
echo "3/4  Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"

# Disable password auth (if you have SSH keys set up)
# Uncomment the next line ONLY if you've already added your SSH key:
# sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"

# Limit login attempts
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"

# Disable X11 forwarding
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"

systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
echo "  ✅ SSH hardened (no root login, max 3 auth tries)"

# ─── 4. Automatic security updates ───
echo "4/4  Enabling automatic security updates..."
apt-get install -y unattended-upgrades > /dev/null 2>&1
dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true
echo "  ✅ Unattended security upgrades enabled"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅  OS hardening complete"
echo ""
echo "  Firewall:   sudo ufw status verbose"
echo "  Fail2Ban:   sudo fail2ban-client status sshd"
echo "  SSH config: /etc/ssh/sshd_config"
echo ""
echo "  ⚠️  If you use SSH keys, also disable password auth:"
echo "     sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config"
echo "     sudo systemctl reload ssh"
echo "═══════════════════════════════════════════"
