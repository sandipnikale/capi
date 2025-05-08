### 📘 Cluster API (CAPI) with `clusterctl`: Upstream Approach

This guide demonstrates how to provision and manage RKE2 and Kubeadm-based clusters using the upstream `clusterctl` tool with Docker as the infrastructure provider. It also covers Rancher Turtle and ClusterClass examples.

---

## 🔧 Prerequisites

* `clusterctl`
* `kubectl`
* `jq`
* `Docker`
* `kind`
* SUSE Linux or any Linux distro

---

## 🧪 RKE2 Cluster with Docker (Upstream Way)

### ✅ Initialize Cluster API Providers

```bash
clusterctl init --bootstrap rke2 --control-plane rke2 --infrastructure docker
```

### ✅ Set Environment Variables

```bash
export NAMESPACE=example
export CLUSTER_NAME=rke2-docker
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
export KIND_IMAGE_VERSION=v1.31.4
export RKE2_VERSION=v1.31.4+rke2r1
```

### ✅ Generate and Apply Cluster Manifest

Template Source:
[https://github.com/rancher/cluster-api-provider-rke2/tree/main/examples/templates](https://github.com/rancher/cluster-api-provider-rke2/tree/main/examples/templates)

```bash
clusterctl generate cluster \
  --from https://raw.githubusercontent.com/rancher/cluster-api-provider-rke2/refs/heads/main/examples/templates/docker/cluster-template.yaml \
  -n ${NAMESPACE} ${CLUSTER_NAME} > docker-rke2-clusterctl.yaml

kubectl apply -f docker-rke2-clusterctl.yaml
```

### ✅ Monitor Cluster Creation

```bash
kubectl get clusters -n ${NAMESPACE}
clusterctl describe cluster ${CLUSTER_NAME} -n ${NAMESPACE}
kubectl get machine -n ${NAMESPACE}
kubectl get machinedeployments -n ${NAMESPACE}
kubectl get machinesets -n ${NAMESPACE}
```

### ✅ Scale Worker Nodes

```bash
kubectl scale machinedeployments ${CLUSTER_NAME}-md-0 -n ${NAMESPACE} --replicas=3
```

### ✅ Control Plane & Kubeconfig

```bash
kubectl get rke2controlplanes -n ${NAMESPACE}
kubectl get secret -n ${NAMESPACE} ${CLUSTER_NAME}-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > ${CLUSTER_NAME}.kubeconfig
```

---

## 🧪 Kubeadm Cluster on Docker

```bash
clusterctl init -i docker -c kubeadm -b kubeadm

export NAMESPACE=example
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
export KUBERNETES_VERSION=v1.31.4
```

```bash
clusterctl generate cluster \
  --from https://raw.githubusercontent.com/sandipnikale/capi/refs/heads/main/docker/kubeadm.yaml \
  -n ${NAMESPACE} kubeadm-docker > docker-kubeadm-clusterctl.yaml

kubectl apply -f docker-kubeadm-clusterctl.yaml
clusterctl describe cluster kubeadm-docker -n ${NAMESPACE}

kubectl get secret -n ${NAMESPACE} kubeadm-docker-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > kubeadm-docker.kubeconfig
```

---

## 🐠 Rancher Turtle Example (Docker RKE2)

```bash
export CLUSTER_NAME=cluster1
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
export KUBERNETES_VERSION=v1.31.4
export NAMESPACE=capi-clusters

curl -s https://raw.githubusercontent.com/rancher-sandbox/rancher-turtles-fleet-example/templates/docker-rke2.yaml | \
envsubst '$CLUSTER_NAME,$CONTROL_PLANE_MACHINE_COUNT,$WORKER_MACHINE_COUNT,$KUBERNETES_VERSION,$NAMESPACE' > cluster1.yaml

kubectl create namespace ${NAMESPACE}
kubectl apply -f cluster1.yaml
```

📝 *Mark namespace for auto-import if using Rancher Fleet.*

---

## 🧹 ClusterClass Example (RKE2 + Docker)

### ✅ Initialize

```bash
clusterctl init --bootstrap rke2 --control-plane rke2 --infrastructure docker
```

### ✅ Apply ClusterClass and Supporting Resources

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/turtles/refs/heads/main/examples/clusterclasses/docker/rke2/clusterclass-docker-rke2.yaml

kubectl apply -f https://raw.githubusercontent.com/rancher/turtles/refs/heads/main/examples/applications/cni/calico/helm-chart.yaml

kubectl apply -f https://raw.githubusercontent.com/sandipnikale/capi/refs/heads/main/clusterclass/loadbalancer.yaml

kubectl apply -f https://raw.githubusercontent.com/sandipnikale/capi/refs/heads/main/clusterclass/cluster-template-topology.yaml
```

---

## 📦 Summary

This markdown provides step-by-step instructions to:

* Use `clusterctl` for bootstrapping both RKE2 and kubeadm clusters.
* Configure Docker infrastructure for CAPI.
* Leverage ClusterClass and Rancher Turtles for declarative and reproducible clusters.
