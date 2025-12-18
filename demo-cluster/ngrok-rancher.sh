#!/bin/bash

set -e

echo "🔧 Installing ngrok..."
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install -y ngrok

echo "📦 Adding Helm repos for Rancher and cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

echo "📄 Applying cert-manager CRDs..."
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.crds.yaml

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
export RANCHER_VERSION=v2.13.0

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
    echo "✅ Rancher service found. Starting background port-forward..."
    nohup kubectl -n cattle-system port-forward svc/rancher 8443:443 > rancher-portforward.log 2>&1 &
    echo "🎉 Port-forward running in background. Access Rancher at https://localhost:8443"
else
    echo "❌ Rancher service not found. Please check installation logs."
fi
