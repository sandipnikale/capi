# Cluster API (CAPI) AWS Setup Guide

Complete guide to create Kubernetes clusters on AWS using Cluster API with Kubeadm bootstrap provider and AWS infrastructure provider.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
- [Create Workload Cluster](#create-workload-cluster)
- [Access Workload Cluster](#access-workload-cluster)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Version Compatibility](#version-compatibility)

---

## Prerequisites

- AWS Account with appropriate permissions
- Management Kubernetes cluster (e.g., Kind, existing K8s cluster)
- Basic understanding of Kubernetes and AWS

---

## Installation Steps

### 1. Setup Management Cluster

Create a Kind cluster to serve as the management cluster:

```bash
# Install Kind (if not already installed)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create management cluster
kind create cluster --name capi-management

# Verify cluster
kubectl cluster-info --context kind-capi-management
kubectl get nodes
```

Or use the automated script:
```bash
curl -O https://raw.githubusercontent.com/sandipnikale/capi/refs/heads/main/demo-cluster/kind-install.sh
chmod +x kind-install.sh
./kind-install.sh
```

### 2. Install AWS CLI

```bash
# Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version

# Configure AWS credentials
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., ap-south-1)
# - Default output format (json)
```

### 3. Create SSH Key Pair

```bash
# Create SSH key pair in AWS (if you don't have one)
aws ec2 create-key-pair \
  --key-name default \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/capi-demo.pem

# Set proper permissions
chmod 400 ~/.ssh/capi-demo.pem

# Verify key was created
aws ec2 describe-key-pairs --key-names default
```

### 4. Install clusterctl

```bash
# Download clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.12.0/clusterctl-linux-amd64 -o clusterctl

# Install
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl

# Verify installation
clusterctl version
```

### 5. Install clusterawsadm

```bash
# Download clusterawsadm
curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.10.0/clusterawsadm-linux-amd64 -o clusterawsadm

# Make executable and move to PATH
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin/

# Verify installation
clusterawsadm version
```

### 6. Export Environment Variables

```bash
# AWS Configuration
export AWS_REGION=ap-south-1
export AWS_ACCESS_KEY_ID=<your-access-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>

# Machine Configuration
export AWS_CONTROL_PLANE_MACHINE_TYPE=t3.xlarge
export AWS_NODE_MACHINE_TYPE=t3.large
export AWS_SSH_KEY_NAME=default

# Optional: For custom AMI (leave empty for auto-selection)
export AWS_AMI_ID=
```

### 7. Create IAM Resources

```bash
# Create required IAM roles and policies for CAPA
clusterawsadm bootstrap iam create-cloudformation-stack

# This creates:
# - controllers.cluster-api-provider-aws.sigs.k8s.io role
# - nodes.cluster-api-provider-aws.sigs.k8s.io role
# - Required policies

# Encode credentials for CAPI
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
```

### 8. Initialize Cluster API

```bash
# Install CAPI with AWS provider
clusterctl init --infrastructure aws

# This installs:
# - Cluster API core components
# - Kubeadm Bootstrap Provider
# - Kubeadm Control Plane Provider
# - AWS Infrastructure Provider

# Wait for all components to be ready
kubectl wait --for=condition=Available deployment --all -n capi-system --timeout=300s
kubectl wait --for=condition=Available deployment --all -n capi-kubeadm-bootstrap-system --timeout=300s
kubectl wait --for=condition=Available deployment --all -n capi-kubeadm-control-plane-system --timeout=300s
kubectl wait --for=condition=Available deployment --all -n capa-system --timeout=300s
```

### 9. Verify Installation

```bash
# Check all providers
kubectl get providers -A

# Expected output:
# NAMESPACE                           NAME                    TYPE                    PROVIDER      VERSION
# capa-system                         infrastructure-aws      InfrastructureProvider  aws           v2.x.x
# capi-kubeadm-bootstrap-system       bootstrap-kubeadm       BootstrapProvider       kubeadm       v1.x.x
# capi-kubeadm-control-plane-system   control-plane-kubeadm   ControlPlaneProvider    kubeadm       v1.x.x
# capi-system                         cluster-api             CoreProvider            cluster-api   v1.x.x

# Check pods are running
kubectl get pods -A
```

---

## Create Workload Cluster

### 1. Check Available AMIs (Optional)

```bash
# List existing Kubeadm AMIs
clusterawsadm ami list

# Note: These are pre-built AMIs with Kubeadm installed
# For other distributions (RKE2, K3s), you need custom AMIs
# RKE2 AMI building guide: https://github.com/rancher/cluster-api-provider-rke2/tree/main/image-builder#aws
```

### 2. Generate Cluster Manifest

```bash
# Generate cluster configuration
clusterctl generate cluster capi-cluster-demo \
  --kubernetes-version v1.32.0 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  > capi-cluster.yaml

# Review the generated manifest
cat capi-cluster.yaml

# Verify environment variables are reflected correctly
grep -E "t3.xlarge|t3.large|ap-south-1|default" capi-cluster.yaml
```

### 3. Apply Cluster Configuration

```bash
# Create the cluster
kubectl apply -f capi-cluster.yaml

# This creates:
# - Cluster resource
# - AWSCluster resource
# - KubeadmControlPlane resource
# - MachineDeployment resource
# - Associated infrastructure resources
```

### 4. Monitor Cluster Creation

```bash
# Watch cluster status
kubectl get clusters --watch

# Check AWS cluster status
kubectl get awscluster

# Detailed cluster description
clusterctl describe cluster capi-cluster-demo

# Check all machines
kubectl get machines -o wide

# Check AWS machines
kubectl get awsmachine -o wide

# Describe AWS cluster for detailed info
kubectl describe awscluster capi-cluster-demo
```

Cluster creation typically takes **10-15 minutes**.

---

## Access Workload Cluster

### 1. Get Kubeconfig

```bash
# Retrieve kubeconfig for workload cluster
clusterctl get kubeconfig capi-cluster-demo > capi-cluster-demo.kubeconfig

# Set KUBECONFIG environment variable
export KUBECONFIG=./capi-cluster-demo.kubeconfig

# Or use --kubeconfig flag
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get nodes
```

### 2. Install CNI (Calico)

Nodes will show `NotReady` until CNI is installed:

```bash
# Install Calico CNI
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for CNI pods to be ready
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get pods -n kube-system --watch

# Verify nodes are Ready
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get nodes
```

### 3. Deploy Test Application

```bash
# Create test deployment
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig create deployment nginx --image=nginx

# Expose deployment
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get deployments
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get pods
kubectl --kubeconfig=./capi-cluster-demo.kubeconfig get svc
```

---

## Troubleshooting

### Check Controller Logs

```bash
# CAPA controller logs
kubectl logs -n capa-system -l control-plane=capa-controller-manager --tail=100

# Core CAPI logs
kubectl logs -n capi-system -l cluster.x-k8s.io/provider=cluster-api --tail=100

# Bootstrap provider logs
kubectl logs -n capi-kubeadm-bootstrap-system -l control-plane=capi-kubeadm-bootstrap-controller-manager --tail=100

# Control plane provider logs
kubectl logs -n capi-kubeadm-control-plane-system -l control-plane=capi-kubeadm-control-plane-controller-manager --tail=100
```

### Check Events

```bash
# All events sorted by timestamp
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Cluster-specific events
kubectl describe cluster capi-cluster-demo | grep -A 20 Events
kubectl describe awscluster capi-cluster-demo | grep -A 20 Events
```

---
### Delete Workload Cluster

```bash
# Delete cluster (this cleans up AWS resources)
kubectl delete cluster capi-cluster-demo

# Wait for deletion to complete (5-10 minutes)
kubectl get cluster --watch

kubectl delete -f capi-cluster.yaml

---
## Useful Commands

### List All Resources

```bash
# All CAPI resources
kubectl get cluster,awscluster,kubeadmcontrolplane,machine,awsmachine,machinedeployment -A

# With wide output
kubectl get machines -o wide
kubectl get awsmachine -o wide
```

### Scale Cluster

```bash
# Scale worker nodes
kubectl scale machinedeployment capi-cluster-demo-md-0 --replicas=2

# Scale control plane (use with caution)
kubectl scale kubeadmcontrolplane capi-cluster-demo-control-plane --replicas=3
```



### Get Cluster Kubeconfig

```bash
# Get kubeconfig
clusterctl get kubeconfig capi-cluster-demo > workload-cluster.kubeconfig

# Use with kubectl
kubectl --kubeconfig=workload-cluster.kubeconfig get nodes
```

---

## Additional Resources

- [Cluster API Documentation](https://cluster-api.sigs.k8s.io/)
- [CAPA Documentation](https://cluster-api-aws.sigs.k8s.io/)
- [Kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [RKE2 Custom AMI Guide](https://github.com/rancher/cluster-api-provider-rke2/tree/main/image-builder#aws)
- [Cluster API Quick Start](https://cluster-api.sigs.k8s.io/user/quick-start.html)

---

## Notes

- **For production use**: Increase control plane and worker node counts, use appropriate instance types, and configure proper networking
- **Custom AMIs**: Required for non-Kubeadm distributions (RKE2 etc.)
- **Regions**: Ensure AMIs are available in your selected region
- **Costs**: Remember to delete resources when not in use to avoid AWS charges
- **Security**: Use IAM roles with least privilege, restrict security groups, and rotate credentials regularly

