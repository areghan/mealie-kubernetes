# Stage 4 — Kubernetes Basics: Mealie + PostgreSQL

## Goal

Deploy Mealie and PostgreSQL directly onto the local Kubernetes cluster using `kubectl`.

This stage introduces:

- Kubernetes Namespaces
- Secrets
- PersistentVolumeClaims
- Deployments
- Services
- ClusterIP
- NodePort
- Kubernetes DNS
- Service discovery
- Persistent storage
- Application-to-database communication

No custom Docker images are built in this stage.

The official Mealie image is pulled directly from GitHub Container Registry.

---

## Architecture

    kind Kubernetes Cluster
    |
    +-- mealie namespace
        |
        +-- Mealie Deployment
        |   |
        |   +-- Mealie Pod
        |       |
        |       +-- Port 9000
        |
        +-- Mealie Service
        |   |
        |   +-- NodePort 30080
        |
        +-- PostgreSQL Deployment
        |   |
        |   +-- PostgreSQL Pod
        |       |
        |       +-- Port 5432
        |
        +-- PostgreSQL Service
        |   |
        |   +-- ClusterIP :5432
        |
        +-- PostgreSQL PVC
            |
            +-- 5Gi Persistent Storage

Application communication:

    Mealie Pod
        |
        | postgres:5432
        v
    PostgreSQL Service
        |
        v
    PostgreSQL Pod
        |
        v
    Persistent Storage

NodePort path:

    Host
        |
        v
    NodePort :30080
        |
        v
    Mealie Service :9000
        |
        v
    Mealie Pod :9000

---

# Environment

Kubernetes:

    v1.36.1

kind:

    v0.33.0-alpha

Docker:

    Docker 29.6.1
    Docker Compose v5.1.4

Operating System:

    Ubuntu 22.04.5 LTS
    WSL2

Kubernetes context:

    kind-mealie-cluster

Verify the active context:

    kubectl config current-context

---

# Project Structure

    stage-4-kubernetes-basics/
    ├── README.md
    ├── namespace.yaml
    ├── postgres-secret.yaml
    ├── postgres-pvc.yaml
    ├── postgres-deployment.yaml
    ├── postgres-service.yaml
    ├── mealie-deployment.yaml
    └── mealie-service.yaml

---

# 1. Namespace

File:

    namespace.yaml

Creates the application namespace:

    mealie

Apply:

    kubectl apply -f namespace.yaml

Verify:

    kubectl get namespace mealie

---

# 2. PostgreSQL Secret

File:

    postgres-secret.yaml

The Secret contains:

    POSTGRES_USER
    POSTGRES_PASSWORD
    POSTGRES_DB

Apply:

    kubectl apply -f postgres-secret.yaml

Verify:

    kubectl get secrets -n mealie

Inspect the Secret metadata without displaying the values:

    kubectl describe secret postgres-secret -n mealie

The Secret is used by both PostgreSQL and Mealie.

---

# 3. PostgreSQL PersistentVolumeClaim

File:

    postgres-pvc.yaml

The PVC requests:

    Storage: 5Gi
    Access Mode: ReadWriteOnce
    StorageClass: standard

Apply:

    kubectl apply -f postgres-pvc.yaml

Initially the PVC entered:

    Pending

This was expected because the standard StorageClass uses:

    WaitForFirstConsumer

The PVC waits for a Pod to consume the storage before binding.

After the PostgreSQL Deployment was created, the PVC became:

    Bound

Verify:

    kubectl get pvc -n mealie

Expected:

    postgres-pvc   Bound   5Gi   RWO   standard

---

# 4. PostgreSQL Deployment

File:

    postgres-deployment.yaml

Image:

    postgres:17

Replicas:

    1

The Deployment:

- Uses the PostgreSQL Secret
- Mounts the PostgreSQL PVC
- Exposes port 5432
- Stores PostgreSQL data at /var/lib/postgresql/data

Apply:

    kubectl apply -f postgres-deployment.yaml

Verify:

    kubectl get deployment -n mealie

    kubectl get pods -n mealie

Expected:

    postgres   1/1   Running

---

# 5. PostgreSQL Service

File:

    postgres-service.yaml

Creates an internal Kubernetes Service.

Name:

    postgres

Type:

    ClusterIP

Port:

    5432

The Service selects PostgreSQL Pods using:

    app: postgres

Apply:

    kubectl apply -f postgres-service.yaml

Verify:

    kubectl get svc -n mealie

The PostgreSQL Service provides the stable DNS name:

    postgres:5432

Mealie does not need to know the PostgreSQL Pod IP.

---

# 6. PostgreSQL Connectivity Test

Before deploying Mealie, PostgreSQL connectivity was tested from inside the Kubernetes cluster.

A temporary PostgreSQL client Pod was launched using:

    kubectl run postgres-client \
      -n mealie \
      --rm \
      -it \
      --restart=Never \
      --image=postgres:17 \
      --env="PGPASSWORD=mealie" \
      -- psql -h postgres -U mealie -d mealie

Inside psql:

    SELECT current_database(), current_user, version();

The connection successfully returned:

    current_database | current_user | version
    -----------------+--------------+----------------
    mealie           | mealie       | PostgreSQL 17.11

This proved that Kubernetes DNS and the PostgreSQL Service were working.

Traffic path:

    Temporary PostgreSQL Client Pod
        |
        v
    Kubernetes DNS
        |
        v
    postgres Service
        |
        v
    PostgreSQL Pod
        |
        v
    mealie database

---

# 7. Mealie Deployment

File:

    mealie-deployment.yaml

Official Mealie image:

    ghcr.io/mealie-recipes/mealie:v3.22.0

No custom Docker image was built in this stage.

Replicas:

    1

Container port:

    9000

Mealie PostgreSQL configuration:

    DB_ENGINE=postgres
    POSTGRES_SERVER=postgres
    POSTGRES_PORT=5432

The database name, username and password are loaded from:

    postgres-secret

Apply:

    kubectl apply -f mealie-deployment.yaml

Verify:

    kubectl get deployment -n mealie

    kubectl get pods -n mealie

Expected:

    mealie   1/1   Running

---

# 8. Mealie to PostgreSQL

Mealie successfully connected to PostgreSQL.

The Mealie logs showed:

    Database connection established.

Database migrations completed successfully.

The application then reported:

    Application startup complete.

And:

    Uvicorn running on http://0.0.0.0:9000

Check the logs:

    kubectl logs deployment/mealie -n mealie

This confirms that Mealie is running against PostgreSQL rather than its default database configuration.

---

# 9. Mealie Service

File:

    mealie-service.yaml

The Service uses:

    Type: NodePort
    Service Port: 9000
    Target Port: 9000
    NodePort: 30080

Apply:

    kubectl apply -f mealie-service.yaml

Verify:

    kubectl get svc -n mealie

Expected:

    mealie     NodePort    9000:30080/TCP
    postgres   ClusterIP   5432/TCP

The networking path is:

    NodePort 30080
        |
        v
    Mealie Service :9000
        |
        v
    Mealie Pod :9000

---

# 10. EndpointSlices

EndpointSlices were used to verify that the Services had healthy backends.

Run:

    kubectl get endpointslices -n mealie

The final cluster showed:

    mealie      10.244.0.8:9000
    postgres    10.244.0.6:5432

This confirms that Kubernetes successfully connected the Services to their respective Pods.

The Service selectors are therefore working correctly.

---

# 11. NodePort Testing

The Mealie NodePort is:

    30080

The NodePort was successfully tested from inside the kind control-plane node.

Run:

    docker exec mealie-cluster-control-plane \
      curl -I http://127.0.0.1:30080

The response was:

    HTTP/1.1 200 OK

with:

    server: uvicorn

This proves that the NodePort itself is working.

Traffic path:

    kind control-plane node
        |
        v
    NodePort :30080
        |
        v
    Mealie Service
        |
        v
    Mealie Pod :9000
        |
        v
    HTTP 200 OK

---

# NodePort and kind Networking Limitation

The kind cluster was created during Stage 3 with the following host mappings:

    Host 8080 -> kind node 80
    Host 8443 -> kind node 443

The cluster was not created with:

    Host 30080 -> kind node 30080

Therefore this command from the WSL host:

    curl -I http://localhost:30080

returns:

    Connection refused

Testing the kind control-plane Docker IP:

    curl -I --max-time 5 http://172.27.0.3:30080

also fails from the WSL host.

However, testing from inside the kind control-plane node works:

    docker exec mealie-cluster-control-plane \
      curl -I http://127.0.0.1:30080

returns:

    HTTP/1.1 200 OK

Therefore:

    Mealie                         WORKING
    PostgreSQL                     WORKING
    Mealie -> PostgreSQL           WORKING
    PostgreSQL Service             WORKING
    Mealie Service                 WORKING
    EndpointSlice                  WORKING
    NodePort                       WORKING
    Host -> kind NodePort          NOT EXPOSED

The issue is the host-to-kind networking configuration, not the Kubernetes application.

The cluster was intentionally not recreated because PostgreSQL and Mealie had already been successfully deployed and verified.

The existing kind mappings:

    8080 -> 80
    8443 -> 443

will become useful during the Ingress stage.

---

# Final Verification

Check all Kubernetes resources:

    kubectl get all -n mealie

Expected Pods:

    mealie       1/1   Running
    postgres     1/1   Running

Expected Services:

    mealie       NodePort   9000:30080
    postgres     ClusterIP  5432

Expected Deployments:

    mealie       1/1
    postgres     1/1

---

# Persistent Storage Verification

Run:

    kubectl get pvc -n mealie

Expected:

    postgres-pvc   Bound   5Gi   RWO   standard

This confirms PostgreSQL has persistent storage.

---

# Endpoint Verification

Run:

    kubectl get endpointslices -n mealie

Expected:

    mealie      10.244.0.8:9000
    postgres    10.244.0.6:5432

---

# Complete Deployment Order

The resources were deployed in this order:

    1. Namespace
           |
           v
    2. PostgreSQL Secret
           |
           v
    3. PostgreSQL PVC
           |
           v
    4. PostgreSQL Deployment
           |
           v
    5. PostgreSQL Service
           |
           v
    6. PostgreSQL connectivity test
           |
           v
    7. Mealie Deployment
           |
           v
    8. Mealie Service
           |
           v
    9. EndpointSlice verification
           |
           v
    10. NodePort verification

This deployment order makes troubleshooting easier because each dependency is verified before moving to the next component.

---

# Key Kubernetes Concepts Learned

## Namespace

Provides logical isolation for application resources.

    mealie

## Secret

Stores database credentials separately from application configuration.

    postgres-secret

## PersistentVolumeClaim

Requests persistent storage for PostgreSQL.

    postgres-pvc

## Deployment

Manages application Pods.

    mealie Deployment
    postgres Deployment

## Service

Provides stable networking and service discovery.

    mealie Service
    postgres Service

## ClusterIP

Used for internal cluster communication.

    postgres:5432

## NodePort

Provides a Node-level port for exposing a Service.

    30080

## EndpointSlice

Shows the actual Pod endpoints selected by a Service.

## Kubernetes DNS

Mealie connects to PostgreSQL using:

    postgres:5432

rather than connecting directly to the PostgreSQL Pod IP.

Kubernetes resolves the service name postgres to the PostgreSQL Service.

---

# Final Architecture

    Host / External Client
             |
             | NodePort 30080
             |
             v
       Mealie Service
          NodePort
             |
             v
        Mealie Pod
          :9000
             |
             | postgres:5432
             v
     PostgreSQL Service
          ClusterIP
             |
             v
       PostgreSQL Pod
          :5432
             |
             v
      PostgreSQL PVC
           5Gi

---

# Stage 4 Result

Stage 4 successfully deployed:

    Mealie v3.22.0
          +
    PostgreSQL 17
          +
    Kubernetes
          +
    Persistent Storage
          +
    Kubernetes Services
          +
    NodePort

The application and database communicate successfully inside Kubernetes.

PostgreSQL is backed by a 5Gi PersistentVolumeClaim.

Mealie successfully connects to PostgreSQL through Kubernetes Service discovery.

The NodePort successfully routes traffic to Mealie from inside the kind node.

The host-level NodePort limitation was identified and documented rather than modifying or recreating the existing cluster.

---

# Cleanup

To remove the Stage 4 application:

    kubectl delete namespace mealie

This removes all resources inside the mealie namespace.

Verify:

    kubectl get namespace mealie

WARNING:

Deleting the namespace also removes the PostgreSQL Deployment, Service, Secret, PVC and associated application resources.

Do not run the cleanup command unless you intentionally want to remove the Stage 4 deployment and its data.

---

# Next Stage

## Stage 5 — Kubernetes Ingress

The next stage will introduce:

- Ingress Controller
- Ingress resource
- Host-based routing
- HTTP routing
- kind port mappings
- External access through the existing 8080 -> 80 mapping
- Browser access to Mealie
- Routing without directly exposing the NodePort

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
    Mealie Service
       |
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
    PostgreSQL Persistent Storage

Stage 4 complete.
