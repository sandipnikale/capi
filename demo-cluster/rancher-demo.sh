#!/bin/bash

set -e

# Function to check and install socat if not installed
install_socat() {
  if ! command -v socat &> /dev/null; then
    echo "🔧 Installing socat..."
    sudo apt-get update && sudo apt-get install -y socat
  else
    echo "✅ socat is already installed."
  fi
}

echo "📦 Adding Helm repos for Rancher and cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

#echo "📄 Applying cert-manager CRDs..."
#kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

echo "🚀 Installing cert-manager..."
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.16.3 \
  --set startupapicheck.nodeSelector."kubernetes\.io/os"=linux \
  --create-namespace \
  --set crds.enabled=true

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

echo "🔍 Checking if Rancher service is online..."
sleep 10
if kubectl get svc rancher -n cattle-system &>/dev/null; then
    echo "✅ Rancher service found."
else
    echo "❌ Rancher service not found. Please check installation logs."
fi

# Now, let's install socat if not installed and create the systemd service
install_socat

echo "🔧 Creating systemd service for kubectl port-forward and socat port forward..."

# Create systemd service file with new name
sudo bash -c 'cat <<EOF > /etc/systemd/system/rancher-port-forward.service
[Unit]
Description=Rancher Port Forwarding Service (kubectl + socat)
After=network.target

[Service]
ExecStart=/bin/bash -c "/usr/local/bin/kubectl -n cattle-system port-forward svc/rancher 8443:443 & /usr/bin/socat TCP-LISTEN:443,fork TCP:127.0.0.1:8443"
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/rancher-portforward.log
StandardError=append:/var/log/rancher-portforward.log

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd and start the service
sudo systemctl daemon-reload
sudo systemctl enable rancher-port-forward.service
sudo systemctl start rancher-port-forward.service

# Display the access URL
echo "🎉 Rancher port-forwarding now running in background as a service."
echo "You can access Rancher at https://${NODE_IP}.sslip.io"
