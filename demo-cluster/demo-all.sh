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
    sudo chown root:docker /var/run/docker.sock
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
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF
    echo "✅ Kind cluster config file created."

    echo "🚀 Creating Kind cluster..."
    kind create cluster --name capi-test --config kind.yaml
    echo "✅ Kind cluster created."
}

# Set kubeconfig
setup_kubeconfig() {
    echo "🚀 Setting up kubeconfig..."
    mkdir -p ~/.kube
    kind get kubeconfig --name capi-test > ~/.kube/config
    chmod 600 ~/.kube/config
    export KUBECONFIG=~/.kube/config
    echo "✅ Kubeconfig is set. You can now use 'kubectl'."
}

# Validate cluster readiness
validate_kubectl() {
    echo "⏳ Waiting 30 seconds for Kubernetes API server to stabilize..."
    sleep 30

    echo "🔍 Checking if any node is in Ready state..."
    if kubectl get nodes 2>/dev/null | grep -q ' Ready '; then
        echo "✅ At least one Kubernetes node is in Ready state."
        kubectl get nodes
    else
        echo "❌ No nodes are in Ready state. Please check the Kind cluster status."
        kubectl get nodes || true
        exit 1
    fi
}

# Install Rancher and set up socat forwarding
install_rancher_stack() {
    echo "📦 Adding Helm repos for Rancher and cert-manager..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm repo update

    echo "📄 Applying cert-manager CRDs..."
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

    echo "🚀 Installing cert-manager..."
    helm upgrade -i cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --version v1.6.1 \
      --set startupapicheck.nodeSelector."kubernetes\.io/os"=linux \
      --create-namespace

    echo "⏳ Waiting for cert-manager components to become available..."
    kubectl wait deployment -n cert-manager cert-manager --for condition=Available=True --timeout=120s
    kubectl wait deployment -n cert-manager cert-manager-cainjector --for condition=Available=True --timeout=120s
    kubectl wait deployment -n cert-manager cert-manager-webhook --for condition=Available=True --timeout=120s

    echo "🌐 Fetching external IP for Rancher hostname..."
    export NODE_IP=$(curl -s https://checkip.amazonaws.com)
    export RANCHER_HOSTNAME="${NODE_IP}.sslip.io"
    export RANCHER_VERSION=v2.11.0

    echo "🐮 Installing Rancher with hostname $RANCHER_HOSTNAME..."
    helm install rancher rancher-latest/rancher \
      --namespace cattle-system \
      --create-namespace \
      --set bootstrapPassword=rancheradmin \
      --set replicas=1 \
      --set hostname="$RANCHER_HOSTNAME" \
      --set global.cattle.psp.enabled=false \
      --version "$RANCHER_VERSION" \
      --wait

    echo "📦 Installing socat if missing..."
    sudo apt-get update && sudo apt-get install -y socat

    echo "🔧 Creating systemd service for socat port-forwarding..."
    cat <<EOF | sudo tee /etc/systemd/system/rancher-forward.service >/dev/null
[Unit]
Description=Forward Rancher port 8444 to localhost:8443 using kubectl and socat
After=network.target

[Service]
ExecStartPre=/bin/bash -c "/usr/local/bin/kubectl -n cattle-system port-forward svc/rancher 8443:443 & sleep 5"
ExecStart=/usr/bin/socat TCP-LISTEN:8444,fork TCP:127.0.0.1:8443
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable rancher-forward.service
    sudo systemctl start rancher-forward.service

    echo "🎉 Rancher should be accessible at: https://${NODE_IP}:8444"
}

# Execution starts here
echo "🎯 Detecting OS..."
detect_os
echo "🟢 OS detected: $OS"

echo "🔧 Configuring system parameters..."
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512
echo "✅ System parameters configured."

install_docker
install_kind
install_helm
install_kubectl
create_kind_cluster
setup_kubeconfig
validate_kubectl
install_rancher_stack

echo "🎉 All done! Run 'kubectl get pods -A' to verify everything is running."
