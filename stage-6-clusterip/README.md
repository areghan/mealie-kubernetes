# Stage 6 — Switch from NodePort → ClusterIP

## Goal

Prepare the Mealie application for Kubernetes Ingress by removing the external NodePort exposure and changing the Mealie Service to an internal ClusterIP Service.

Stage 4 introduced Mealie using a NodePort Service.

Stage 6 changes the architecture so that Mealie is no longer directly exposed through a NodePort.

The target architecture is:

    Browser
       |
       v
    Ingress
       |
       v
    Mealie Service
       |
       | ClusterIP :9000
       v
    Mealie Pod :9000
       |
       | postgres:5432
       v
    PostgreSQL Service
       |
       v
    PostgreSQL Pod
       |
       v
    PostgreSQL PVC

Ingress will become the external entry point in a later stage.

---

# Project Structure

    stage-6-clusterip/
    ├── README.md
    └── mealie-service.yaml

Stage 6 intentionally contains a new Service manifest rather than modifying the Stage 4 manifest.

Stage 4 remains as a historical record of the original NodePort configuration.

Stage 6 represents the next architectural step.

---

# Why NodePort Must Go Away

In Stage 4, Mealie was exposed using:

    NodePort

The Service configuration included:

    port: 9000
    targetPort: 9000
    nodePort: 30080

This created the following traffic path:

    Host
       |
       v
    NodePort :30080
       |
       v
    Mealie Service
       |
       v
    Mealie Pod :9000

NodePort was useful during the early Kubernetes learning stages because it provided a simple way to expose the application.

However, NodePort is not the architecture we want when introducing Ingress.

---

# Target Architecture

Stage 6 changes the traffic path to:

    Browser
       |
       v
    Ingress
       |
       v
    Mealie ClusterIP Service
       |
       v
    Mealie Pod :9000

The Ingress Controller will eventually become the external entry point.

The Mealie Service therefore only needs to be reachable from inside the Kubernetes cluster.

This is exactly what ClusterIP provides.

---

# Stage 4 vs Stage 6

## Stage 4

    Mealie Service
    Type: NodePort
    Service Port: 9000
    NodePort: 30080

The Service was exposed as:

    9000:30080/TCP

---

## Stage 6

    Mealie Service
    Type: ClusterIP
    Service Port: 9000
    Target Port: 9000

The Service is now exposed internally as:

    9000/TCP

There is no NodePort.

---

# Stage 6 Service

File:

    mealie-service.yaml

The Stage 6 Service is:

    apiVersion: v1
    kind: Service
    metadata:
      name: mealie
      namespace: mealie
    spec:
      type: ClusterIP

      selector:
        app: mealie

      ports:
        - protocol: TCP
          port: 9000
          targetPort: 9000

---

# Full Service YAML

The complete Stage 6 Service configuration is:

    apiVersion: v1
    kind: Service
    metadata:
      name: mealie
      namespace: mealie
    spec:
      type: ClusterIP

      selector:
        app: mealie

      ports:
        - protocol: TCP
          port: 9000
          targetPort: 9000

---

# Important Service Changes

The Stage 4 Service used:

    type: NodePort

Stage 6 uses:

    type: ClusterIP

The Stage 4 Service also contained:

    nodePort: 30080

The Stage 6 Service contains no nodePort field.

This removes direct NodePort exposure.

---

# Applying the Stage 6 Service

The Stage 6 Service was applied using:

    kubectl apply -f stage-6-clusterip/mealie-service.yaml

Kubernetes updated the existing Mealie Service.

The resulting Services were:

    NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
    mealie     ClusterIP   10.96.222.42    <none>        9000/TCP
    postgres   ClusterIP   10.96.146.203   <none>        5432/TCP

The important result is:

    mealie → ClusterIP → 9000/TCP

instead of:

    mealie → NodePort → 9000:30080/TCP

---

# Service Verification

The Service was inspected using:

    kubectl describe svc mealie -n mealie

The Service reported:

    Name:                     mealie
    Namespace:                mealie
    Selector:                 app=mealie
    Type:                     ClusterIP
    IP:                       10.96.222.42
    Port:                     9000/TCP
    TargetPort:               9000/TCP
    Endpoints:                10.244.0.8:9000
    Internal Traffic Policy:  Cluster

This confirms that the Service is now a ClusterIP Service.

---

# Service Selector

The Service continues to use:

    selector:
      app: mealie

The Mealie Deployment uses the matching Pod label:

    labels:
      app: mealie

This allows Kubernetes to associate the Service with the correct Pod.

The Service endpoint was:

    10.244.0.8:9000

This means the Service was successfully routing traffic to the Mealie Pod.

---

# PostgreSQL Service

PostgreSQL was already using ClusterIP in Stage 4.

Its Service remains:

    postgres
    Type: ClusterIP
    Port: 5432

Therefore the application architecture now has:

    Mealie
      |
      | postgres:5432
      v
    PostgreSQL ClusterIP Service
      |
      v
    PostgreSQL Pod

Both application and database Services are internal to the Kubernetes cluster.

---

# Testing ClusterIP

Because ClusterIP Services are internal to Kubernetes, we cannot directly access the Mealie Service through the host using its ClusterIP address.

Instead, Kubernetes port-forwarding can be used for temporary testing.

The command used was:

    kubectl port-forward -n mealie svc/mealie 9001:9000

This maps:

    Local Port:      9001
    Service Port:    9000

The traffic path becomes:

    localhost:9001
          |
          | kubectl port-forward
          v
    Mealie Service :9000
          |
          v
    Mealie Pod :9000

Port 9001 was used locally because port 9000 was already occupied by another kubectl port-forward process.

---

# Port 9000 Conflict

An initial attempt was made using:

    kubectl port-forward -n mealie svc/mealie 9000:9000

Kubernetes returned:

    Unable to listen on port 9000

The local port was already being used.

The port was investigated with:

    sudo lsof -i :9000

The output showed:

    kubectl 12477 regan TCP localhost:9000 (LISTEN)

The process was identified using:

    ps -fp 12477

The process was:

    kubectl port-forward -n mealie svc/mealie 9000:9000

Therefore, instead of terminating the existing process, port 9001 was used for the Stage 6 test.

---

# Initial Port-Forward Error

During one of the initial port-forward attempts, Kubernetes returned:

    failed to connect to localhost:9000 inside namespace
    connect: connection refused

The Mealie Pod was then inspected.

The Pod was:

    READY   STATUS
    1/1     Running

The logs showed:

    Application startup complete.

and:

    Uvicorn running on http://0.0.0.0:9000

The Pod had also recently restarted.

After the Pod was healthy, the port-forward was retried using local port 9001.

---

# Successful Port-Forward

The successful command was:

    kubectl port-forward -n mealie svc/mealie 9001:9000

The application was then tested using:

    curl -I http://127.0.0.1:9001

The response was:

    HTTP/1.1 200 OK

The response also confirmed:

    server: uvicorn

This proved that the ClusterIP Service successfully routed traffic to Mealie.

---

# Mealie API Test

The application API was tested using:

    curl http://127.0.0.1:9001/api/app/about

The application returned:

    {
      "production": true,
      "version": "v3.22.0",
      "demoStatus": false,
      "allowSignup": false,
      "allowPasswordLogin": true,
      "defaultGroupSlug": null,
      "defaultHouseholdSlug": null,
      "enableOidc": false,
      "oidcRedirect": false,
      "oidcProviderName": "OAuth",
      "tokenTime": 48,
      "allowedIframeHosts": [
        "youtube.com",
        "youtube-nocookie.com",
        "vimeo.com",
        "player.vimeo.com"
      ]
    }

This confirms that the Mealie application is running successfully and that version:

    v3.22.0

is being served through the ClusterIP Service.

---

# Successful Test Architecture

The final successful test path was:

    WSL Host
       |
       | localhost:9001
       v
    kubectl port-forward
       |
       v
    Mealie ClusterIP Service
       |
       | :9000
       v
    Mealie Pod
       |
       | :9000
       v
    Uvicorn / Mealie
       |
       v
    HTTP 200 OK

This confirms that external NodePort exposure is no longer required for basic application testing.

---

# Why Port-Forward Is Only a Test Mechanism

Port-forwarding is being used here only to verify that the ClusterIP Service works.

It is not intended to become the permanent application exposure mechanism.

The desired future architecture is:

    Browser
       |
       v
    Ingress Controller
       |
       v
    Mealie ClusterIP Service
       |
       v
    Mealie Pod

The ClusterIP Service remains internal while Ingress handles external traffic.

---

# Current Kubernetes Architecture

The current Stage 6 architecture is:

    Kubernetes Cluster
    |
    +-- mealie namespace
        |
        +-- Mealie Deployment
        |      |
        |      +-- Mealie Pod :9000
        |
        +-- Mealie Service
        |      |
        |      +-- ClusterIP :9000
        |
        +-- PostgreSQL Deployment
        |      |
        |      +-- PostgreSQL Pod :5432
        |
        +-- PostgreSQL Service
        |      |
        |      +-- ClusterIP :5432
        |
        +-- PostgreSQL PVC
               |
               +-- 5Gi persistent storage

---

# Stage 6 Verification

The following checks were completed successfully:

    ✓ Mealie Service changed from NodePort to ClusterIP
    ✓ NodePort 30080 removed
    ✓ Mealie Service still selects the correct Pod
    ✓ Mealie endpoint exists
    ✓ Mealie Pod is Running
    ✓ Mealie Pod is Ready
    ✓ Mealie is listening on port 9000
    ✓ ClusterIP port-forward works
    ✓ HTTP request returns 200 OK
    ✓ Mealie API responds
    ✓ Mealie v3.22.0 confirmed

---

# Stage 6 Result

Stage 6 successfully removed direct NodePort exposure from Mealie.

Before:

    Mealie
       |
       v
    NodePort :30080
       |
       v
    Host

After:

    Mealie
       |
       v
    ClusterIP :9000
       |
       v
    Internal Kubernetes traffic

Temporary testing is performed using:

    kubectl port-forward

This prepares the application for the next architectural step.

---

# Important Project Structure Decision

The Stage 4 Service manifest was intentionally not modified.

Stage 4 continues to document the original NodePort implementation.

Stage 6 introduces a new Service manifest representing the new architecture:

    stage-4-kubernetes-basics/
    └── mealie-service.yaml
        └── NodePort

    stage-6-clusterip/
    └── mealie-service.yaml
        └── ClusterIP

This preserves the progression of the project and makes the architectural evolution visible in Git history.

---

# Automation Consideration

The Stage 5 startup script currently references the Stage 4 Kubernetes manifests.

Therefore:

    stage-5-scripts-automation/scripts/startup.sh

still references:

    stage-4-kubernetes-basics/mealie-service.yaml

That file contains the original NodePort configuration.

Stage 6 intentionally does not modify Stage 5 yet.

Automation will need to be updated in a future step so that the automated deployment uses the current ClusterIP architecture.

The previous stages are preserved as historical milestones.

---

# Lessons Learned

## NodePort

NodePort is useful for simple external access during early Kubernetes learning.

However, it is not necessary when an Ingress Controller will provide external access.

## ClusterIP

ClusterIP provides internal Kubernetes networking.

It is the appropriate Service type for an application that will sit behind an Ingress.

## Service Discovery

Mealie continues to use Kubernetes Services rather than Pod IP addresses.

The database remains available through:

    postgres:5432

## Port-Forward

Port-forwarding provides temporary local access to an internal Service.

It is useful for testing ClusterIP applications without exposing them through NodePort.

## Ingress Preparation

Removing NodePort means the application is now ready for an Ingress Controller to become the external entry point.

---

# Next Stage

## Stage 7 — Kubernetes Ingress

The next stage will introduce:

- Ingress Controller
- Ingress resource
- HTTP routing
- Host-based routing
- kind port mappings
- External access through port 80
- Browser access to Mealie
- ClusterIP-backed application routing

Target architecture:

    Browser
       |
       | localhost:8080
       v
    Kind Node :80
       |
       v
    Ingress Controller
       |
       v
    Mealie ClusterIP Service :9000
       |
       v
    Mealie Pod :9000
       |
       | postgres:5432
       v
    PostgreSQL ClusterIP Service :5432
       |
       v
    PostgreSQL Pod
       |
       v
    PostgreSQL PVC

Stage 6 complete.
