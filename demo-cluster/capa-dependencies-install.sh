#!/bin/bash

set -e

log() {
  echo -e "\n🔧 $1"
}

check_installed() {
  command -v "$1" >/dev/null 2>&1
}

# Update package index once
log "Updating package list..."
sudo apt-get update -qq

# Install make, curl, unzip if not present
for pkg in make curl unzip software-properties-common; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    log "Installing $pkg..."
    sudo apt-get install -y "$pkg" >/dev/null
  fi
done

# Install Ansible if not installed
if check_installed ansible; then
  ansible --version | head -n1 | awk '{print "✅ Ansible already installed: " $2}'
else
  log "Installing Ansible..."
  sudo apt-add-repository --yes --update ppa:ansible/ansible >/dev/null
  sudo apt-get install -y ansible >/dev/null
  ansible --version | head -n1 | awk '{print "✅ Ansible installed: " $2}'
fi

# Install AWS CLI if not installed
if check_installed aws; then
  aws --version | awk '{print "✅ AWS CLI already installed: " $1}'
else
  log "Installing AWS CLI..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -qq /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
  aws --version | awk '{print "✅ AWS CLI installed: " $1}'
fi

# Install Packer if not installed
if check_installed packer; then
  packer --version | awk '{print "✅ Packer already installed: " $1}'
else
  log "Installing Packer..."
  curl -s https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y packer >/dev/null
  packer --version | awk '{print "✅ Packer installed: " $1}'
fi

# Install Packer Amazon plugin if not installed
if [ -d "${HOME}/.packer.d/plugins/github.com/hashicorp/amazon" ]; then
  echo "✅ Packer Amazon plugin already installed."
else
  log "Installing Packer Amazon plugin..."
  packer plugins install github.com/hashicorp/amazon >/dev/null
  echo "✅ Packer Amazon plugin installed."
fi

# Install direnv if not installed
if check_installed direnv; then
  direnv --version | awk '{print "✅ Direnv already installed: " $1}'
else
  log "Installing direnv..."
  sudo apt-get install -y direnv >/dev/null
  direnv --version | awk '{print "✅ Direnv installed: " $1}'
fi

log "🎉 All tools are installed and up to date!"
