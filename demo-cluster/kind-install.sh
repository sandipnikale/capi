#!/bin/bash
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Unsupported OS. Exiting."
        exit 1
    fi
}

# Set system parameters before proceeding
echo "🔧 Configuring system parameters..."
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512
echo "✅ System parameters configured."

# Install Docker
install_docker() {
    if command_exists docker; then
        echo "✅ Docker is already installed."
        return
    fi

    echo "🚀 Installing Docker..."
    case "$OS" in
        ubuntu | debian)
            sudo apt update
            sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos | rhel | rocky | almalinux)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        opensuse* | sles)
            sudo zypper install -y docker
            ;;
        *)
            echo "❌ Unsupported OS for Docker installation."
            exit 1
            ;;
    esac

    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    echo "✅ Docker installation complete."
}

# Install Kind
install_kind() {
    if command_exists kind; then
        echo "✅ Kind is already installed."
        return
    fi

    echo "🚀 Installing Kind..."
    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep "tag_name" | cut -d '"' -f 4)
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ Kind installation complete."
}

# Install Helm
install_helm() {
    if command_exists helm; then
        echo "✅ Helm is already installed."
        return
    fi

    echo "🚀 Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    sudo ./get_helm.sh
    rm -f get_helm.sh
    echo "✅ Helm installation complete."
}

# Install kubectl
install_kubectl() {
    if command_exists kubectl; then
        echo "✅ kubectl is already installed."
        return
    fi

    echo "🚀 Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "✅ kubectl installation complete."
}

# Create Kind Cluster
create_kind_cluster() {
    echo "🚀 Creating Kind cluster configuration..."
    cat <<EOF > kind.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: capi-test
nodes:
- role: control-plane
  image: kindest/node:v1.34.0
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF
    echo "✅ Kind cluster config file created."

    echo "🚀 Creating Kind cluster..."
    sudo kind create cluster --name capi-test --config kind.yaml
    echo "✅ Kind cluster created."
}

# Set kubeconfig
setup_kubeconfig() {
    echo "🚀 Setting up kubeconfig..."
    sudo mkdir -p ~/.kube
    sudo kind get kubeconfig --name capi-test | sudo tee ~/.kube/config >/dev/null
    sudo chmod 600 ~/.kube/config
    export KUBECONFIG=~/.kube/config
    sudo chmod 644 /home/ubuntu/.kube/config 
    echo "✅ Kubeconfig is set. You can now use 'kubectl' commands."
}

# Run the installation
echo "🎯 Detecting OS..."
detect_os
echo "🟢 OS detected: $OS"

install_docker
install_kind
install_helm
install_kubectl
create_kind_cluster
setup_kubeconfig

echo "🎉 Installation complete! Run 'kubectl get nodes' to verify the cluster."
