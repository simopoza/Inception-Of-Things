#!/bin/bash

set -e

# Update system and install GUI + SSH
sudo apt-get update
echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 lightdm openssh-server
echo "vagrant:mannahriVMS" | sudo chpasswd
sudo ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service

# Disable firewall
sudo ufw disable

# Install K3s in server mode with external IP
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-external-ip=192.168.56.110" sh -

# Wait until node-token is generated
echo "Waiting for K3s to generate node-token..."
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
done

# Share token and public key
mkdir -p /vagrant/shared
cp /var/lib/rancher/k3s/server/node-token /vagrant/shared/node-token

# Generate SSH key for passwordless access
sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
sudo -u vagrant cp /home/vagrant/.ssh/id_rsa.pub /vagrant/shared/id_rsa.pub

# Set up kubectl config for vagrant user
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

# Optional: Make kubectl accessible globally
sudo ln -sf /usr/local/bin/kubectl /usr/bin/kubectl

echo "✅ K3s server setup complete. Rebooting for GUI..."
sudo reboot
