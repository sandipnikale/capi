#!/bin/bash

set -e

echo "🔧 Checking and installing Docker, Helm, kubectl, and clusterctl on SLES 15 SP6..."

# Install Docker if not present
if ! command -v docker &>/dev/null; then
  echo "📦 Installing Docker..."
  sudo zypper refresh
  sudo zypper install -y docker
fi

# Restart Docker service and enable it
echo "🔄 Restarting Docker service..."
sudo systemctl enable docker
sudo systemctl restart docker

# Configure system parameters
echo "⚙️ Configuring system parameters..."
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=512

# Create Docker network if not present
if ! docker network inspect kind &>/dev/null; then
  echo "🌐 Creating Docker network 'kind'..."
  docker network create --driver=bridge --subnet=172.19.0.0/16 --gateway=172.19.0.1 \
    --opt "com.docker.network.bridge.enable_ip_masquerade"="true" \
    --opt "com.docker.network.driver.mtu"="1350" kind
else
  echo "✔ Docker network 'kind' already exists."
fi

# Install Helm
if ! command -v helm &>/dev/null; then
  echo "📦 Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✔ Helm is already installed."
fi

# Install hardcoded kubectl version (v1.30.1)
if ! command -v kubectl &>/dev/null; then
  echo "📦 Installing kubectl v1.30.1..."
  curl -LO "https://dl.k8s.io/release/v1.30.1/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "✔ kubectl is already installed."
fi

# Install latest clusterctl
if ! command -v clusterctl &>/dev/null; then
  echo "📦 Installing latest clusterctl..."
  CLUSTERCTL_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cluster-api/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -LO "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64"
  chmod +x clusterctl-linux-amd64
  sudo mv clusterctl-linux-amd64 /usr/local/bin/clusterctl
else
  echo "✔ clusterctl is already installed."
fi

# Install K3s
if ! command -v k3s &>/dev/null; then
  echo "🚀 Installing K3s (latest stable)..."
  curl -sfL https://get.k3s.io | sh -
  echo "⏳ Waiting for K3s to initialize..."
  sleep 30
else
  echo "✔ K3s is already installed."
fi

# Configure kubeconfig
echo "🔐 Configuring kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

echo "⏳ Waiting for Kubernetes API to be ready..."
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until /usr/local/bin/kubectl --kubeconfig=$KUBECONFIG get nodes >/dev/null 2>&1; do
  echo "⌛ Kubernetes API not ready yet. Retrying in 5s..."
  sleep 5
done
echo "✅ Kubernetes API is ready!"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.crds.yaml

# Add Helm repositories
echo "📡 Adding Helm repositories..."
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

# Install cert-manager with updated command
echo "🔐 Installing cert-manager..."
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.2 \
  --atomic 

# Install Rancher using specified hostname and version
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

# Add turtles cluster repo using updated API version
echo "📁 Adding 'turtles' cluster repo to Rancher..."
kubectl apply -f - <<EOF
apiVersion: catalog.cattle.io/v1
kind: ClusterRepo
metadata:
  name: turtles
  namespace: fleet-local
spec:
  url: https://rancher.github.io/turtles
EOF

echo
echo "✅ Rancher is successfully installed!"
echo "🌍 Access it at: https://${RANCHER_HOSTNAME}"
