#!/bin/bash

set -e

# Update and install GUI + SSH
sudo apt-get update
echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 lightdm openssh-server netcat
echo "vagrant:mannahriVMSW" | sudo chpasswd
sudo ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

# Disable firewall
sudo ufw disable

# Wait for shared folder contents
echo "Waiting for shared folder to contain node-token and SSH keys..."
while [ ! -f /vagrant/shared/node-token ] || [ ! -f /vagrant/shared/id_rsa ] || [ ! -f /vagrant/shared/id_rsa.pub ]; do
  sleep 2
done

# Set up SSH key for accessing the server
mkdir -p /home/vagrant/.ssh
cp /vagrant/shared/id_rsa /home/vagrant/.ssh/id_rsa
chmod 600 /home/vagrant/.ssh/id_rsa
chown vagrant:vagrant /home/vagrant/.ssh/id_rsa

# Accept server's public key for reverse SSH
cat /vagrant/shared/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Join K3s cluster as agent
SERVER_IP="192.168.56.110"
AGENT_IP="192.168.56.111"
NODE_TOKEN=$(cat /vagrant/shared/node-token)

curl -sfL https://get.k3s.io | sh -s - agent \
  --server "https://${SERVER_IP}:6443" \
  --token "${NODE_TOKEN}" \
  --node-ip "${AGENT_IP}" \
  --node-external-ip "${AGENT_IP}"

# Restart K3s agent to ensure it's active
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent

echo "✅ K3s agent setup complete. Rebooting for GUI..."
sudo reboot
