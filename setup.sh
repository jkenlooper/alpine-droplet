#!/bin/sh

# Enable openssh server
rc-update add sshd default

# Configure networking
cat > /etc/network/interfaces <<-EOF
iface lo inet loopback
iface eth0 inet dhcp
EOF

ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

rc-update add net.eth0 default
rc-update add net.lo boot

# Create root ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Other vendor metadata sources are listed here from cloudinit docs
# https://cloudinit.readthedocs.io/en/latest/topics/datasources.html

# Grab config from DigitalOcean metadata service
cat > /bin/do-init <<-'EOF'
#!/bin/sh
resize2fs /dev/vda

# https://docs.digitalocean.com/reference/api/metadata-api/
wget -T 5 http://169.254.169.254/metadata/v1/hostname    -q -O /etc/hostname
wget -T 5 http://169.254.169.254/metadata/v1/public-keys -q -O /root/.ssh/authorized_keys
wget -T 5 http://169.254.169.254/metadata/v1/user-data   -q -O /root/user-data
wget -T 5 http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address -q -O /root/public-ipv4-address

# Reject any future use of the metadata service.
# https://github.com/canonical/cloud-init/blob/main/cloudinit/config/cc_disable_ec2_metadata.py#L18
ip route add prohibit 169.254.169.254

hostname -F /etc/hostname
chmod 0600 /root/.ssh/authorized_keys

# Only execute user-data if first line has a shebang.
if [ -f /root/user-data ]; then
  chmod 0400 /root/user-data
  has_shebang="$(awk 'NR==1 && /^#!/' /root/user-data)"
  if [ -n "$has_shebang" ]; then
    chmod 0500 /root/user-data
  fi
  if [ -x /root/user-data ]; then
    /root/user-data
    # Clean up user-data in case it has sensitive content
    shred -fuz /root/user-data || rm -f /root/user-data
  fi
fi

# The do-init is a one off, so delete and zap it after it runs.
rc-update del do-init default
openrc
rc-service do-init zap
exit 0
EOF

# Create do-init OpenRC service
cat > /etc/init.d/do-init <<-EOF
#!/sbin/openrc-run
depend() {
    need net.eth0
}
command="/bin/do-init"
command_args=""
pidfile="/tmp/do-init.pid"
EOF

# Make do-init and service executable
chmod +x /etc/init.d/do-init
chmod +x /bin/do-init

# Enable do-init service
rc-update add do-init default
