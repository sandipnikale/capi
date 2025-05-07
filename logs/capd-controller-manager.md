## CAPD Cluster1 Event Timeline (From `capd-controller-manager` logs)

### 🧩 Cluster & DockerCluster Events

```yaml
- time: 05:03:17.930509 # I0507 05:03:17.930509       1 cluster_controller.go:233]  "msg"="Reconciling Cluster" "cluster"="cluster1" "namespace"="capi-clusters"
  event: Cluster reconciliation started
  object: Cluster/cluster1
  namespace: capi-clusters
  log: 'I0507 05:03:17.930509       1 cluster_controller.go:233]  "msg"="Reconciling Cluster" "cluster"="cluster1" "namespace"="capi-clusters"'

- time: 05:03:18.070678 # I0507 05:03:18.070678       1 dockercluster_controller.go:98]  "msg"="Reconciling DockerCluster" "dockerCluster"="cluster1" "namespace"="capi-clusters"
  event: DockerCluster reconciling
  object: DockerCluster/cluster1
  namespace: capi-clusters
  log: 'I0507 05:03:18.070678       1 dockercluster_controller.go:98]  "msg"="Reconciling DockerCluster" "dockerCluster"="cluster1" "namespace"="capi-clusters"'

- time: 05:03:18.165207 # I0507 05:03:18.165207       1 dockercluster_controller.go:141]  "msg"="Cluster infrastructure created" "cluster"="cluster1" "namespace"="capi-clusters"
  event: DockerCluster infrastructure created
  object: DockerCluster/cluster1
  namespace: capi-clusters
  log: 'I0507 05:03:18.165207       1 dockercluster_controller.go:141]  "msg"="Cluster infrastructure created" "cluster"="cluster1" "namespace"="capi-clusters"'
```

### 🧠 KubeadmControlPlane Events (Indicative of Kubeadm usage)

```yaml
- time: 05:03:18.062659 # I0507 05:03:18.062659       1 kubeadm_control_plane_controller.go:196]  "msg"="Reconcile KubeadmControlPlane" "name"="cluster1-control-plane" "namespace"="capi-clusters"
  event: Reconcile KubeadmControlPlane
  object: cluster1-control-plane
  namespace: capi-clusters
  log: 'I0507 05:03:18.062659       1 kubeadm_control_plane_controller.go:196]  "msg"="Reconcile KubeadmControlPlane" "name"="cluster1-control-plane" "namespace"="capi-clusters"'

- time: 05:03:18.654506 # I0507 05:03:18.654506       1 kubeadm_control_plane_controller.go:505]  "msg"="Waiting for first control plane machine to be provisioned" "name"="cluster1-control-plane" "namespace"="capi-clusters"
  event: Waiting for first control plane node
  object: cluster1-control-plane
  namespace: capi-clusters
  log: 'I0507 05:03:18.654506       1 kubeadm_control_plane_controller.go:505]  "msg"="Waiting for first control plane machine to be provisioned" "name"="cluster1-control-plane" "namespace"="capi-clusters"'
```

### ⚙️ Machine Events

```yaml
- time: 05:03:19.063526 # I0507 05:03:19.063526       1 machine_controller_noderef.go:104]  "msg"="Getting node for machine" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"
  event: Getting node for machine
  object: cluster1-control-plane-n5c9s
  log: 'I0507 05:03:19.063526       1 machine_controller_noderef.go:104]  "msg"="Getting node for machine" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"'

- time: 05:03:29.063625 # I0507 05:03:29.063625       1 machine_controller.go:306]  "msg"="Machine infrastructure is ready" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"
  event: Control plane machine infrastructure ready
  object: cluster1-control-plane-n5c9s
  log: 'I0507 05:03:29.063625       1 machine_controller.go:306]  "msg"="Machine infrastructure is ready" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"'

- time: 05:03:31.065232 # I0507 05:03:31.065232       1 machine_controller.go:313]  "msg"="Machine bootstrap data is ready" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"
  event: Control plane bootstrap ready
  object: cluster1-control-plane-n5c9s
  log: 'I0507 05:03:31.065232       1 machine_controller.go:313]  "msg"="Machine bootstrap data is ready" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"'

- time: 05:03:37.261579 # I0507 05:03:37.261579       1 machine_controller.go:369]  "msg"="Setting status.Ready to true" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"
  event: Control plane machine marked Ready
  object: cluster1-control-plane-n5c9s
  log: 'I0507 05:03:37.261579       1 machine_controller.go:369]  "msg"="Setting status.Ready to true" "machine"="cluster1-control-plane-n5c9s" "namespace"="capi-clusters"'

- time: 05:03:34.781419 # I0507 05:03:34.781419       1 machine_controller.go:306]  "msg"="Machine infrastructure is ready" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"
  event: Worker machine infrastructure ready
  object: cluster1-md-0-756fcd65f8-ml8cf
  log: 'I0507 05:03:34.781419       1 machine_controller.go:306]  "msg"="Machine infrastructure is ready" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"'

- time: 05:03:35.773102 # I0507 05:03:35.773102       1 machine_controller.go:313]  "msg"="Machine bootstrap data is ready" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"
  event: Worker machine bootstrap ready
  object: cluster1-md-0-756fcd65f8-ml8cf
  log: 'I0507 05:03:35.773102       1 machine_controller.go:313]  "msg"="Machine bootstrap data is ready" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"'

- time: 05:03:44.772513 # I0507 05:03:44.772513       1 machine_controller.go:369]  "msg"="Setting status.Ready to true" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"
  event: Worker machine marked Ready
  object: cluster1-md-0-756fcd65f8-ml8cf
  log: 'I0507 05:03:44.772513       1 machine_controller.go:369]  "msg"="Setting status.Ready to true" "machine"="cluster1-md-0-756fcd65f8-ml8cf" "namespace"="capi-clusters"'
```

### 🧱 MachineDeployment & MachineSet Events

```yaml
- time: 05:03:18.060647 # I0507 05:03:18.060647       1 machinedeployment_controller.go:129]  "msg"="Reconcile MachineDeployment" "machineDeployment"="cluster1-md-0" "namespace"="capi-clusters"
  event: Reconciling MachineDeployment
  object: cluster1-md-0
  namespace: capi-clusters
  log: 'I0507 05:03:18.060647       1 machinedeployment_controller.go:129]  "msg"="Reconcile MachineDeployment" "machineDeployment"="cluster1-md-0" "namespace"="capi-clusters"'

- time: 05:03:18.066940 # I0507 05:03:18.066940       1 machineset_controller.go:122]  "msg"="Reconcile MachineSet" "machineset"="cluster1-md-0-756fcd65f8" "namespace"="capi-clusters"
  event: Reconciling MachineSet
  object: cluster1-md-0-756fcd65f8
  namespace: capi-clusters
  log: 'I0507 05:03:18.066940       1 machineset_controller.go:122]  "msg"="Reconcile MachineSet" "machineset"="cluster1-md-0-756fcd65f8" "namespace"="capi-clusters"'
```
