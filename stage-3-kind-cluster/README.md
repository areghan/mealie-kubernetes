# Stage 3 — kind Cluster Creation

## Goal

Create a local Kubernetes cluster using kind that is suitable for learning Kubernetes and eventually deploying the Mealie application.

The cluster is configured with an Ingress-ready node and host port mappings so that HTTP and HTTPS traffic can later enter the Kubernetes cluster.

## Prerequisites

The following were completed during Stage 0:

* WSL2
* Ubuntu 22.04.5 LTS
* Docker Desktop
* Docker Engine 29.6.1
* kubectl v1.36.1
* kind v0.33.0-alpha

## Cluster Configuration

The cluster is named:

```text
mealie-cluster
```

It contains one node:

```text
mealie-cluster-control-plane
```

The node acts as the Kubernetes control plane and is also available to run workloads.

## kind Configuration

The cluster is created using:

```text
kind-cluster.yaml
```

Configuration:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

name: mealie-cluster

nodes:
  - role: control-plane

    labels:
      ingress-ready: "true"

    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP

      - containerPort: 443
        hostPort: 8443
        protocol: TCP
```

## Ingress-Ready Node

The control-plane node has the following label:

```text
ingress-ready=true
```

Verified with:

```bash
kubectl get nodes --show-labels
```

This label prepares the node for the Ingress stage.

The label itself does not install an Ingress controller.

## Port Mappings

The kind node has the following host mappings:

```text
Host              kind Node
──────────────────────────────
localhost:8080 →  :80
localhost:8443 →  :443
```

Verified with:

```bash
docker port mealie-cluster-control-plane
```

The Kubernetes API server is also exposed locally by kind:

```text
127.0.0.1:39813 → :6443
```

This allows kubectl to communicate with the Kubernetes API server.

## Cluster Creation

The cluster was created using:

```bash
kind create cluster --config kind-cluster.yaml --wait 5m
```

kind successfully:

* Created the control-plane node
* Installed the Kubernetes control plane
* Installed the CNI
* Installed the default StorageClass
* Waited for the control plane to become ready
* Configured the kubectl context

The active context is:

```text
kind-mealie-cluster
```

## Cluster Verification

### Cluster information

```bash
kubectl cluster-info
```

Result:

```text
Kubernetes control plane is running
CoreDNS is running
```

### Node verification

```bash
kubectl get nodes
```

Result:

```text
NAME                           STATUS   ROLES           VERSION
mealie-cluster-control-plane   Ready    control-plane   v1.36.1
```

### System Pods

```bash
kubectl get pods -A
```

The Kubernetes system components were successfully running, including:

* CoreDNS
* etcd
* kube-apiserver
* kube-controller-manager
* kube-proxy
* kube-scheduler
* kindnet
* local-path-provisioner

All verified system Pods were in the `Running` state.

### kind cluster verification

```bash
kind get clusters
```

The project cluster was confirmed as:

```text
mealie-cluster
```

## Important Note

Another kind cluster named `kind` already existed on the workstation from previous Kubernetes work.

It was not modified or deleted.

The cluster used for this project is:

```text
mealie-cluster
```

## Architecture

```text
Windows
   │
   ▼
WSL2
   │
   ▼
Docker Desktop
   │
   ▼
┌──────────────────────────────────────┐
│          kind Kubernetes             │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ mealie-cluster-control-plane   │  │
│  │                                │  │
│  │ Kubernetes v1.36.1             │  │
│  │ ingress-ready=true             │  │
│  └────────────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
       │                  │
       │                  │
   :8080 → :80       :8443 → :443
```

## Stage 3 Completion Criteria

* [x] kind installed
* [x] kind cluster configuration created
* [x] Cluster created successfully
* [x] Control-plane node Ready
* [x] Kubernetes v1.36.1 running
* [x] CNI installed
* [x] StorageClass installed
* [x] Ingress-ready node label configured
* [x] HTTP port mapping configured
* [x] HTTPS port mapping configured
* [x] Kubernetes system Pods verified
* [x] kubectl context configured
* [x] Cluster verified with kubectl
* [x] Cluster verified with kind

## Result

Stage 3 completed successfully.

A functional local Kubernetes cluster is now available for the Mealie project.

No Mealie workloads have been deployed to Kubernetes yet.

## Next Stage

**Stage 4 — Kubernetes Fundamentals**

The next stage will introduce Kubernetes concepts using small test workloads before deploying Mealie.

Topics will include:

* Pods
* Deployments
* Services
* Labels and selectors
* Namespaces
* kubectl fundamentals
* Application exposure

The Mealie application will remain unchanged while these Kubernetes fundamentals are learned.

