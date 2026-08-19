# Stage 5 — Scripts & Automation

## Goal

Make the Kubernetes deployment usable, repeatable and testable through automation scripts.

Stage 4 introduced the manual Kubernetes deployment of Mealie and PostgreSQL.

Stage 5 builds on that deployment by introducing:

- Bash automation
- Kubernetes deployment ordering
- Readiness checks
- Idempotent deployments
- Automated health checks
- Automated application testing
- Kubernetes service discovery testing

The Stage 5 scripts reuse the Kubernetes manifests created in Stage 4 rather than duplicating them.

---

# Project Structure

    stage-5-scripts-automation/
    ├── README.md
    └── scripts/
        ├── startup.sh
        └── test.sh

The Stage 5 scripts use the manifests from:

    stage-4-kubernetes-basics/

The overall project structure is:

    mealie-projects/
    ├── stage-0-workstation/
    ├── stage-1-mealie/
    ├── stage-3-kind-cluster/
    ├── stage-4-kubernetes-basics/
    └── stage-5-scripts-automation/
        ├── README.md
        └── scripts/
            ├── startup.sh
            └── test.sh

---

# Stage 5 Architecture

    Stage 5 Scripts
          |
          +--------------------+
          |                    |
          v                    v
    startup.sh              test.sh
          |                    |
          v                    v
    Stage 4 YAML          Kubernetes Checks
          |
          v
    Kubernetes Cluster
          |
          +-----------------------+
          |                       |
          v                       v
      Mealie Pod            PostgreSQL Pod
       :9000                    :5432
          |                       |
          v                       v
    Mealie Service         PostgreSQL Service
      NodePort                  ClusterIP
          |
          v
      PostgreSQL PVC

---

# Why Automation?

Before Stage 5, the Kubernetes deployment required manually running several commands.

For example:

    kubectl apply -f namespace.yaml
    kubectl apply -f postgres-secret.yaml
    kubectl apply -f postgres-pvc.yaml
    kubectl apply -f postgres-deployment.yaml
    kubectl apply -f postgres-service.yaml
    kubectl apply -f mealie-deployment.yaml
    kubectl apply -f mealie-service.yaml

This works, but it becomes repetitive and makes it easier to forget a step.

Stage 5 replaces the manual process with:

    ./scripts/startup.sh

And provides automated validation through:

    ./scripts/test.sh

---

# startup.sh

The startup script is responsible for deploying and reconciling the Stage 4 Kubernetes resources.

The script does not contain duplicate Kubernetes manifests.

Instead, it references the manifests already stored in:

    stage-4-kubernetes-basics/

This keeps the project maintainable and gives each stage a clear responsibility.

---

# startup.sh — Full Script

    #!/usr/bin/env bash

    set -euo pipefail

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    K8S_DIR="${PROJECT_ROOT}/stage-4-kubernetes-basics"
    NAMESPACE="mealie"

    echo "========================================"
    echo " Mealie Kubernetes Startup"
    echo "========================================"

    echo
    echo "Checking Kubernetes context..."
    kubectl config current-context

    echo
    echo "Applying namespace..."
    kubectl apply -f "${K8S_DIR}/namespace.yaml"

    echo
    echo "Applying PostgreSQL Secret..."
    kubectl apply -f "${K8S_DIR}/postgres-secret.yaml"

    echo
    echo "Applying PostgreSQL PVC..."
    kubectl apply -f "${K8S_DIR}/postgres-pvc.yaml"

    echo
    echo "Applying PostgreSQL Deployment..."
    kubectl apply -f "${K8S_DIR}/postgres-deployment.yaml"

    echo
    echo "Applying PostgreSQL Service..."
    kubectl apply -f "${K8S_DIR}/postgres-service.yaml"

    echo
    echo "Waiting for PostgreSQL Pod to become Ready..."
    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=postgres \
      --timeout=180s

    echo
    echo "PostgreSQL is Ready."

    echo
    echo "Applying Mealie Deployment..."
    kubectl apply -f "${K8S_DIR}/mealie-deployment.yaml"

    echo
    echo "Applying Mealie Service..."
    kubectl apply -f "${K8S_DIR}/mealie-service.yaml"

    echo
    echo "Waiting for Mealie Pod to become Ready..."
    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=mealie \
      --timeout=180s

    echo
    echo "Mealie is Ready."

    echo
    echo "========================================"
    echo " Deployment Complete"
    echo "========================================"

    echo
    echo "Current resources:"
    kubectl get pods,svc,pvc -n "${NAMESPACE}"

---

# startup.sh Breakdown

## Strict Bash Mode

The script starts with:

    set -euo pipefail

This makes the script fail rather than silently continuing when an important command fails.

The three options provide:

    -e

Exit when a command fails.

    -u

Treat unset variables as errors.

    pipefail

Ensure a failure inside a pipeline is detected.

---

# Project Root Detection

The script uses:

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

This allows the script to locate the project root automatically.

The Stage 4 Kubernetes manifests are then located using:

    K8S_DIR="${PROJECT_ROOT}/stage-4-kubernetes-basics"

This means the script does not depend on the user being inside the Stage 5 directory.

---

# Location Independence

The script was tested from the Stage 5 scripts directory:

    ~/mealie-projects/stage-5-scripts-automation/scripts

It successfully executed.

It was then tested from the project root:

    ~/mealie-projects

using:

    ./stage-5-scripts-automation/scripts/startup.sh

It also successfully executed.

Therefore the script can locate the Stage 4 manifests regardless of the current working directory.

---

# Deployment Ordering

The startup script deliberately follows this order:

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
    6. Wait for PostgreSQL
           |
           v
    7. Mealie Deployment
           |
           v
    8. Mealie Service
           |
           v
    9. Wait for Mealie
           |
           v
    10. Display current resources

The ordering matters because Mealie depends on PostgreSQL.

---

# Readiness Checks

The startup script uses:

    kubectl wait

rather than arbitrary delays such as:

    sleep 30

For PostgreSQL:

    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=postgres \
      --timeout=180s

For Mealie:

    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=mealie \
      --timeout=180s

This means the script waits for Kubernetes to report that the Pods are actually Ready.

---

# Idempotency

Idempotency means that running the same operation repeatedly should not create unwanted duplicate resources or break an existing deployment.

Stage 5 uses:

    kubectl apply

rather than destructive commands.

For example:

    kubectl apply -f namespace.yaml

If the namespace already exists, Kubernetes reports:

    namespace/mealie unchanged

If the Deployment already exists and does not require modification:

    deployment.apps/postgres unchanged

The same applies to the Services and PVC.

---

# Idempotency Test

The startup script was executed against the existing Stage 4 deployment.

The output included:

    namespace/mealie unchanged

    persistentvolumeclaim/postgres-pvc unchanged

    deployment.apps/postgres unchanged

    service/postgres unchanged

    deployment.apps/mealie unchanged

    service/mealie unchanged

The existing Pods were also confirmed Ready:

    pod/postgres-6bd965bdb7-9q2cq condition met

    pod/mealie-54f9577854-zp7kt condition met

This demonstrated that the startup script can safely reconcile the existing deployment.

---

# test.sh

The test script verifies that the Kubernetes deployment is healthy after startup.

It checks:

- Kubernetes context
- Namespace
- PostgreSQL Pod
- PostgreSQL Service
- PostgreSQL PVC
- Mealie Pod
- Mealie Service
- Mealie EndpointSlice
- PostgreSQL EndpointSlice
- Mealie HTTP response

---

# test.sh — Full Script

    #!/usr/bin/env bash

    set -euo pipefail

    NAMESPACE="mealie"

    echo "========================================"
    echo " Mealie Kubernetes Test Suite"
    echo "========================================"

    echo
    echo "Checking Kubernetes context..."
    kubectl config current-context

    echo
    echo "Checking namespace..."
    kubectl get namespace "${NAMESPACE}" >/dev/null
    echo "✓ Namespace exists"

    echo
    echo "Checking PostgreSQL Pod..."
    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=postgres \
      --timeout=30s
    echo "✓ PostgreSQL Pod is Ready"

    echo
    echo "Checking PostgreSQL Service..."
    kubectl get service postgres -n "${NAMESPACE}" >/dev/null
    echo "✓ PostgreSQL Service exists"

    echo
    echo "Checking PostgreSQL PVC..."
    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=jsonpath='{.status.phase}'=Bound \
      persistentvolumeclaim/postgres-pvc \
      --timeout=30s
    echo "✓ PostgreSQL PVC is Bound"

    echo
    echo "Checking Mealie Pod..."
    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=mealie \
      --timeout=30s
    echo "✓ Mealie Pod is Ready"

    echo
    echo "Checking Mealie Service..."
    kubectl get service mealie -n "${NAMESPACE}" >/dev/null
    echo "✓ Mealie Service exists"

    echo
    echo "Checking Service endpoints..."
    kubectl get endpointslice \
      -n "${NAMESPACE}" \
      -l kubernetes.io/service-name=mealie \
      --no-headers >/dev/null
    echo "✓ Mealie EndpointSlice exists"

    kubectl get endpointslice \
      -n "${NAMESPACE}" \
      -l kubernetes.io/service-name=postgres \
      --no-headers >/dev/null
    echo "✓ PostgreSQL EndpointSlice exists"

    echo
    echo "Testing Mealie application from inside the cluster..."

    kubectl run mealie-test-client \
      --namespace "${NAMESPACE}" \
      --rm \
      --stdin \
      --tty=false \
      --restart=Never \
      --image=curlimages/curl:8.10.1 \
      -- \
      curl \
      --fail \
      --silent \
      --show-error \
      --max-time 10 \
      http://mealie:9000/api/app/about \
      >/dev/null

    echo "✓ Mealie application responded successfully"

    echo
    echo "========================================"
    echo " All Tests Passed"
    echo "========================================"

    echo
    echo "Kubernetes resources are healthy:"
    kubectl get pods,svc,pvc -n "${NAMESPACE}"

---

# test.sh Breakdown

## Kubernetes Context

The script first checks the current Kubernetes context:

    kubectl config current-context

The tested context was:

    kind-mealie-cluster

---

# Namespace Test

The script verifies that the Mealie namespace exists:

    kubectl get namespace "${NAMESPACE}"

Successful result:

    ✓ Namespace exists

---

# PostgreSQL Pod Test

The PostgreSQL Pod must be Ready:

    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=postgres \
      --timeout=30s

Successful result:

    ✓ PostgreSQL Pod is Ready

---

# PostgreSQL Service Test

The script verifies that the PostgreSQL Service exists:

    kubectl get service postgres -n "${NAMESPACE}"

Successful result:

    ✓ PostgreSQL Service exists

---

# PostgreSQL PVC Test

The script verifies that the PostgreSQL PVC is Bound:

    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=jsonpath='{.status.phase}'=Bound \
      persistentvolumeclaim/postgres-pvc \
      --timeout=30s

Successful result:

    ✓ PostgreSQL PVC is Bound

The PVC provides:

    5Gi
    ReadWriteOnce
    standard StorageClass

---

# Mealie Pod Test

The script waits for the Mealie Pod to become Ready:

    kubectl wait \
      --namespace "${NAMESPACE}" \
      --for=condition=Ready \
      pod \
      -l app=mealie \
      --timeout=30s

Successful result:

    ✓ Mealie Pod is Ready

---

# Mealie Service Test

The script verifies that the Mealie Service exists:

    kubectl get service mealie -n "${NAMESPACE}"

Successful result:

    ✓ Mealie Service exists

The Service uses:

    Type: NodePort
    Port: 9000
    NodePort: 30080

---

# EndpointSlice Tests

The test script checks the EndpointSlices for both services.

Mealie:

    kubectl get endpointslice \
      -n "${NAMESPACE}" \
      -l kubernetes.io/service-name=mealie

PostgreSQL:

    kubectl get endpointslice \
      -n "${NAMESPACE}" \
      -l kubernetes.io/service-name=postgres

Successful results:

    ✓ Mealie EndpointSlice exists

    ✓ PostgreSQL EndpointSlice exists

This verifies that Kubernetes has EndpointSlice resources associated with the Services.

---

# Application Test

The test script launches a temporary curl client inside the Kubernetes cluster.

The temporary client uses:

    curlimages/curl:8.10.1

The client requests:

    http://mealie:9000/api/app/about

The request uses the Kubernetes Service name:

    mealie

This tests Kubernetes DNS and Service discovery.

Traffic path:

    Temporary Test Pod
          |
          v
    Kubernetes DNS
          |
          v
    mealie Service
          |
          v
    Mealie Pod :9000
          |
          v
    /api/app/about

The curl command uses:

    --fail

so HTTP failures cause the test to fail.

It also uses:

    --silent
    --show-error
    --max-time 10

The temporary Pod is removed automatically using:

    --rm

---

# Why the Application Test Runs Inside Kubernetes

The Stage 4 kind cluster uses host port mappings:

    Host 8080 -> kind node 80
    Host 8443 -> kind node 443

The Mealie NodePort is:

    30080

The kind cluster was not configured with:

    Host 30080 -> kind node 30080

Therefore:

    curl http://localhost:30080

from the WSL host does not work.

However, the NodePort works from inside the kind control-plane node.

Because Stage 5 is testing the Kubernetes application rather than host networking, the test script uses a temporary Pod inside the cluster.

This gives the following test path:

    Test Pod
       |
       v
    mealie:9000
       |
       v
    Mealie Service
       |
       v
    Mealie Pod

This avoids making the automated test dependent on the host-to-kind NodePort mapping.

---

# Running the Scripts

## Start or Reconcile the Application

From the project root:

    ./stage-5-scripts-automation/scripts/startup.sh

The script can also be executed from inside the Stage 5 directory:

    ./scripts/startup.sh

---

# Test the Deployment

From the project root:

    ./stage-5-scripts-automation/scripts/test.sh

Or from the Stage 5 directory:

    ./scripts/test.sh

---

# Stage 5 Test Result

The complete test suite was successfully executed.

The following checks passed:

    ✓ Namespace exists
    ✓ PostgreSQL Pod is Ready
    ✓ PostgreSQL Service exists
    ✓ PostgreSQL PVC is Bound
    ✓ Mealie Pod is Ready
    ✓ Mealie Service exists
    ✓ Mealie EndpointSlice exists
    ✓ PostgreSQL EndpointSlice exists
    ✓ Mealie application responded successfully

Final result:

    ========================================
     All Tests Passed
    ========================================

---

# Final Kubernetes State

The successful test showed:

    NAME                            READY   STATUS
    pod/mealie-54f9577854-zp7kt     1/1     Running
    pod/postgres-6bd965bdb7-9q2cq   1/1     Running

Services:

    service/mealie
    Type: NodePort
    Port: 9000:30080

    service/postgres
    Type: ClusterIP
    Port: 5432

Persistent storage:

    postgres-pvc
    Status: Bound
    Capacity: 5Gi
    Access Mode: RWO
    StorageClass: standard

---

# Stage 5 Concepts Learned

## Automation

Repeated Kubernetes commands can be placed inside executable scripts.

## Ordering

Dependent services should be started and checked in a logical order.

PostgreSQL must be available before relying on Mealie's database connection.

## Readiness

Use Kubernetes readiness conditions instead of arbitrary sleep timers.

## Idempotency

Using kubectl apply allows the script to be run repeatedly without creating duplicate resources.

## Service Discovery

Applications communicate using Kubernetes Service names instead of Pod IP addresses.

Example:

    postgres:5432

and:

    mealie:9000

## Automated Testing

A test script can verify the health of the Kubernetes deployment and the application itself.

## Temporary Test Pods

A temporary curl container can be used to test application connectivity from inside the Kubernetes cluster.

---

# Stage 5 Result

Stage 5 successfully converted the manual Stage 4 deployment into a repeatable and testable workflow.

The project now supports:

    ./scripts/startup.sh

for deployment and reconciliation.

And:

    ./scripts/test.sh

for automated verification.

The workflow is now:

    Stage 4
    Manual Kubernetes Deployment
             |
             v
    Stage 5
    Automated Deployment
             |
             v
    Automated Testing
             |
             v
    Repeatable Kubernetes Workflow

---

# Next Stage

## Stage 6 — Kubernetes Ingress

The next stage will introduce Kubernetes Ingress and external application routing.

Planned concepts:

- Ingress Controller
- Ingress resources
- Host-based routing
- HTTP routing
- kind port mappings
- Browser access
- External traffic routing
- Kubernetes networking

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
    PostgreSQL PVC

Stage 5 complete.
