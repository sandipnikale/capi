# 🚀 Deploy RKE2 Workload Cluster on AWS using Cluster API (CAPA + CAPRKE2)

This guide walks through the process of deploying an RKE2 workload cluster on AWS using [Cluster API](https://cluster-api.sigs.k8s.io/) with CAPA (AWS provider) and CAPRKE2 (RKE2 provider).

---

## 📦 Prerequisites

- Kind (used for the management cluster)
- AWS CLI installed and configured
- Docker
- `make`, `jq`, `ansible`, `packer`
- A default VPC in your AWS account

---

## 🛠️ Install Required CLI Tools

### 1. Install `clusterctl`

```bash
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.9.6/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
clusterctl version
```

---

### 2. Install `clusterawsadm`

> The `clusterawsadm` CLI helps manage IAM resources for the AWS provider.

```bash
curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.8.2/clusterawsadm-linux-amd64 -o clusterawsadm
chmod +x clusterawsadm
sudo mv clusterawsadm /usr/local/bin
clusterawsadm version
```

---

## 🌍 Export AWS Environment Variables

Either export manually or use `direnv`.

```bash
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_SESSION_TOKEN=<session-token> # (if using MFA)
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

# Cluster-specific environment
export CONTROL_PLANE_MACHINE_COUNT=3
export WORKER_MACHINE_COUNT=1
export RKE2_VERSION=v1.30.2+rke2r1
export AWS_NODE_MACHINE_TYPE=t3a.large
export AWS_CONTROL_PLANE_MACHINE_TYPE=t3a.large
export AWS_SSH_KEY_NAME="aws-ssh-key"
export AWS_AMI_ID="ami-id"
```

---

## 🏗️ Bootstrap IAM

Create the CloudFormation stack in your AWS account:

```bash
clusterawsadm bootstrap iam create-cloudformation-stack
```

---

## 🚀 Deploy Cluster API Providers

Install the providers (CAPA and CAPRKE2):

```bash
clusterctl init --bootstrap rke2 --control-plane rke2 --infrastructure aws
```

---

## 🖼️ Build a Custom RKE2 AMI

Before creating the workload cluster, build a custom AMI:

1. Clone the repo:
   ```bash
   git clone https://github.com/rancher/cluster-api-provider-rke2.git
   cd cluster-api-provider-rke2
   ```

2. Ensure you have a default VPC:
   ```bash
   aws ec2 create-default-vpc
   ```

3. Modify the AMI filter in the Packer template:

   Open `image-builder/aws/opensuse-leap-156.json` and update:
   ```json
   "ami_filter_name": "openSUSE-Leap-15-6-v20250131-hvm-ssd-x86_64-5535c495-72d4-4355-b169-54ffa874f849"
   ```

4. Build the custom AMI:

   From the root (where the `Makefile` is):

   ```bash
   DEBUG=1 make build-aws-opensuse-leap-156 RKE2_VERSION=1.31.7+rke2r1
   ```

   > 💡 On first attempt, you may see:
   > ```
   > Error launching source instance: OptInRequired...
   > ```
   > Visit the [AWS Marketplace link](https://aws.amazon.com/marketplace) for the SUSE image and **subscribe/accept the terms**.

---

## 📄 Generate and Apply Cluster YAML

1. Generate the YAML manifest:

   ```bash
   clusterctl generate cluster --from https://github.com/rancher/cluster-api-provider-rke2/blob/main/examples/templates/aws/cluster-template.yaml -n example-aws rke2-aws > aws-rke2-clusterctl.yaml
   ```

2. Apply it to the management cluster:

   ```bash
   kubectl apply -f aws-rke2-clusterctl.yaml
   ```

---

## 🔍 Monitor Cluster Provisioning

Check cluster status:

```bash
clusterctl describe cluster -n example-aws rke2-aws
```

---

## 🗕️ Get Kubeconfig of the Workload Cluster

```bash
kubectl get secret rke2-aws-kubeconfig -n example-aws -o jsonpath='{.data.value}' | base64 --decode > example-aws.kubeconfig
```

Now use it:
```bash
export KUBECONFIG=$(pwd)/example-aws.kubeconfig
kubectl get nodes
```

---

## ✅ You're Done!

You now have a fully working RKE2 cluster on AWS managed via Cluster API!

