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

# Wait for the shared folder to contain the required files
echo "Waiting for shared folder to contain node-token and id_rsa.pub..."
while [ ! -f /vagrant/shared/node-token ] || [ ! -f /vagrant/shared/id_rsa.pub ]; do
  sleep 2
done

# Copy the public key for passwordless SSH
mkdir -p /home/vagrant/.ssh
cat /vagrant/shared/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# K3s agent join configuration
SERVER_IP="192.168.56.110"
AGENT_IP="192.168.56.111"
NODE_TOKEN=$(cat /vagrant/shared/node-token)

# Install K3s agent using recommended CLI flags
curl -sfL https://get.k3s.io | sh -s - agent \
  --server "https://${SERVER_IP}:6443" \
  --token "${NODE_TOKEN}" \
  --node-ip "${AGENT_IP}" \
  --node-external-ip "${AGENT_IP}"

# Ensure agent is running
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent

echo "✅ K3s agent setup complete. Rebooting for GUI..."
sudo reboot