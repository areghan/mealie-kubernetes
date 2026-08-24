# Stage 7 — Ingress (NGINX) on kind

## Goal

Introduce Kubernetes Ingress to provide real HTTP routing for the Mealie application.

Stage 6 changed Mealie from a NodePort Service to a ClusterIP Service.

Stage 7 introduces an NGINX Ingress Controller so that external HTTP traffic can be routed to the internal Mealie ClusterIP Service.

The architecture is now closer to a production-style Kubernetes deployment:

    Client
       |
       | HTTP
       v
    kind Node :80
       |
       v
    NGINX Ingress Controller
       |
       v
    Kubernetes Ingress
       |
       v
    Mealie ClusterIP Service :9000
       |
       v
    Mealie Pod :9000
       |
       | postgres:5432
       v
    PostgreSQL ClusterIP Service
       |
       v
    PostgreSQL Pod
       |
       v
    PostgreSQL PVC

---

# Project Structure

    stage-7-ingress/
    ├── README.md
    └── ingress.yaml

The Stage 7 directory contains the Ingress resource and documentation.

The NGINX Ingress Controller itself is installed into the Kubernetes cluster.

---

# Previous Architecture

Before Stage 7, the application used a ClusterIP Service.

The Stage 6 architecture was:

    Client
       |
       | kubectl port-forward
       v
    Mealie ClusterIP Service :9000
       |
       v
    Mealie Pod :9000

ClusterIP is an internal Kubernetes Service type.

It is appropriate for an application that will be accessed through an Ingress Controller.

---

# Stage 7 Architecture

Stage 7 introduces an Ingress layer:

    Client
       |
       | localhost:8080
       v
    kind Node :80
       |
       v
    NGINX Ingress Controller
       |
       v
    Ingress Resource
       |
       | /api
       v
    Mealie ClusterIP Service :9000
       |
       v
    Mealie Pod :9000

This separates external HTTP routing from the application's internal Service.

---

# Why Use Ingress?

Without Ingress, applications often need to be exposed using:

- NodePort
- LoadBalancer
- External reverse proxies
- Port forwarding

Ingress provides a Kubernetes-native HTTP routing layer.

It can route incoming HTTP requests to different Kubernetes Services based on:

- Host
- Path
- Host and Path combination

For this stage, path-based routing is introduced first.

---

# NodePort to ClusterIP to Ingress

The project has evolved through three networking stages.

## Stage 4 — NodePort

    Client
       |
       v
    NodePort :30080
       |
       v
    Mealie Service
       |
       v
    Mealie Pod :9000

NodePort provided simple external access.

---

## Stage 6 — ClusterIP

    Client
       |
       | port-forward
       v
    Mealie ClusterIP :9000
       |
       v
    Mealie Pod :9000

NodePort was removed.

---

## Stage 7 — Ingress

    Client
       |
       | HTTP :8080
       v
    kind Node :80
       |
       v
    NGINX Ingress
       |
       v
    Mealie ClusterIP :9000
       |
       v
    Mealie Pod :9000

Ingress is now responsible for HTTP routing.

---

# kind Port Mappings

The Stage 3 kind configuration already contained the required HTTP port mapping.

The existing configuration is:

    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP

      - containerPort: 443
        hostPort: 8443
        protocol: TCP

Therefore Stage 7 did not require a change to:

    stage-3-kind-cluster/kind-cluster.yaml

The existing mapping provides:

    Host port 8080
          |
          v
    kind node port 80

This allows the host to send HTTP traffic to the NGINX Ingress Controller.

---

# Why localhost:8080 Is Used

The current kind cluster maps:

    hostPort: 8080

to:

    containerPort: 80

Therefore the Stage 7 HTTP endpoint is:

    http://localhost:8080

The project does not use:

    http://localhost

because the current kind configuration does not map host port 80.

Using port 8080 also avoids unnecessary changes to the existing kind cluster.

---

# NGINX Ingress Controller

The NGINX Ingress Controller was installed using the kind-specific deployment:

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.14.0/deploy/static/provider/kind/deploy.yaml

The controller was installed into:

    ingress-nginx

namespace.

---

# Verify NGINX Controller

The controller was verified using:

    kubectl get pods -n ingress-nginx

The controller reached:

    READY   STATUS
    1/1     Running

The controller Pod was:

    ingress-nginx-controller-6d5f985fd4-7rq5l

with:

    IP: 10.244.0.9

---

# NGINX Service

The controller Service was inspected using:

    kubectl get svc -n ingress-nginx

The controller Service reported:

    ingress-nginx-controller
    Type: LoadBalancer
    Port: 80:32645/TCP
    Port: 443:30285/TCP

The external IP showed:

    <pending>

This is expected in the local kind environment because this is not a cloud Kubernetes cluster with a cloud LoadBalancer implementation.

The kind port mapping is used for external access instead.

---

# IngressClass

The available IngressClass was checked using:

    kubectl get ingressclass

The result included:

    NAME    CONTROLLER
    nginx   k8s.io/ingress-nginx

The Ingress resource therefore uses:

    ingressClassName: nginx

---

# Initial NGINX Connectivity Test

Before creating an Ingress rule, the following command was executed:

    curl -I http://localhost:8080

The result was:

    HTTP/1.1 404 Not Found

This was expected.

At this point:

    localhost:8080
          |
          v
    kind :80
          |
          v
    NGINX Ingress Controller
          |
          v
    No matching Ingress rule

Therefore NGINX correctly returned:

    404 Not Found

This demonstrated that traffic was reaching the NGINX controller before any application routing rule existed.

---

# Ingress Resource

The Stage 7 Ingress resource is stored in:

    ingress.yaml

It creates an Ingress named:

    mealie

inside the:

    mealie

namespace.

---

# Full ingress.yaml

The complete Stage 7 Ingress configuration is:

    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: mealie
      namespace: mealie
    spec:
      ingressClassName: nginx

      rules:
        - http:
            paths:
              - path: /api
                pathType: Prefix
                backend:
                  service:
                    name: mealie
                    port:
                      number: 9000

---

# Ingress Configuration Breakdown

## API Version

The resource uses:

    apiVersion: networking.k8s.io/v1

This is the current Kubernetes API version used for the Ingress resource.

---

# Ingress Class

The configuration contains:

    ingressClassName: nginx

This tells Kubernetes that the NGINX Ingress Controller should process this Ingress resource.

---

# Path Routing

The rule contains:

    path: /api

and:

    pathType: Prefix

This means requests beginning with:

    /api

are routed to the Mealie Service.

For example:

    /api/app/about

matches:

    /api

because `/api` is a prefix of `/api/app/about`.

---

# Backend Service

The backend is:

    service:
      name: mealie
      port:
        number: 9000

The Ingress therefore sends matching traffic to:

    mealie:9000

The `mealie` Service is the ClusterIP Service created during Stage 6.

The Ingress does not send traffic directly to the Pod IP.

The routing path is:

    Ingress
       |
       v
    mealie Service :9000
       |
       v
    Mealie Pod :9000

---

# Host vs Path Routing

Ingress can route traffic based on either hosts or paths.

## Path-Based Routing

The Stage 7 configuration uses path routing:

    /api

Example:

    http://localhost:8080/api/app/about

The request matches:

    /api

and is sent to:

    mealie:9000

---

# Host-Based Routing

Host routing uses the HTTP Host header.

For example, an Ingress could eventually route:

    mealie.example.com

to:

    mealie:9000

The architecture would be:

    mealie.example.com
            |
            v
       NGINX Ingress
            |
            v
       mealie:9000

Host-based routing has not been implemented in this stage.

Stage 7 begins with path-based routing.

---

# Why Rewrite Rules Exist

Ingress rewrite rules are needed when the external URL path does not match the path expected by the backend application.

For example, suppose the external URL is:

    /mealie/api/app/about

but the application expects:

    /api/app/about

The Ingress would need to transform:

    /mealie/api/app/about

into:

    /api/app/about

This is a path rewrite.

---

# No Rewrite Required in Stage 7

The current Stage 7 configuration does not require a rewrite rule.

The client sends:

    /api/app/about

The Ingress matches:

    /api

and forwards the request while preserving the path.

The backend therefore receives:

    /api/app/about

This is already the path expected by Mealie.

Adding a rewrite rule would therefore be unnecessary for the current configuration.

---

# Applying the Ingress

The Ingress was applied using:

    kubectl apply -f ~/mealie-projects/stage-7-ingress/ingress.yaml

The resource was then checked using:

    kubectl get ingress -n mealie

The result was:

    NAME     CLASS   HOSTS   ADDRESS   PORTS
    mealie   nginx   *                 80

This confirmed that the Ingress resource was created and associated with the NGINX IngressClass.

---

# Inspecting the Ingress

The resource was inspected using:

    kubectl describe ingress mealie -n mealie

The important output was:

    Name:             mealie
    Namespace:        mealie
    Ingress Class:    nginx

The routing rule was:

    Host        Path  Backends
    ----        ----  --------
    *
                /api   mealie:9000

The backend endpoint was:

    10.244.0.3:9000

This confirmed that the Ingress Controller had successfully discovered the Mealie Service and its backend endpoint.

---

# Ingress Controller Sync

The Ingress description showed:

    Normal  Sync
    nginx-ingress-controller
    Scheduled for sync

This confirmed that the NGINX Ingress Controller had processed the new Ingress resource.

---

# Application Test

The main Stage 7 test was:

    curl http://localhost:8080/api/app/about

The request returned the Mealie application response.

The response included:

    {
      "production": true,
      "version": "v3.22.0",
      "demoStatus": false,
      "allowSignup": false,
      "allowPasswordLogin": true
    }

This confirmed that the request travelled through the Ingress Controller to the Mealie application.

---

# HTTP Status Test

The application status was explicitly tested using:

    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/app/about

The result was:

    200

This confirms that the complete HTTP routing path successfully returned an HTTP 200 response.

---

# Testing an Unmatched Path

The following request was also tested:

    curl -I http://localhost:8080/not-api

The result was:

    HTTP/1.1 404 Not Found

This is expected because the Ingress only defines a route for:

    /api

The request:

    /not-api

does not match the configured path.

This demonstrates that the Ingress is actually performing path-based routing.

---

# Final Routing Test

The successful application request travelled through:

    curl
       |
       | http://localhost:8080/api/app/about
       v
    Host port 8080
       |
       v
    kind node port 80
       |
       v
    NGINX Ingress Controller
       |
       v
    Ingress /api rule
       |
       v
    mealie ClusterIP Service :9000
       |
       v
    Mealie Pod :9000
       |
       v
    /api/app/about
       |
       v
    HTTP 200

---

# HEAD vs GET Observation

During testing, the following command was initially used:

    curl -I http://localhost:8080/api/app/about

This sends an HTTP HEAD request.

The response was:

    HTTP/1.1 404 Not Found

The normal GET request was successful:

    curl http://localhost:8080/api/app/about

and returned the Mealie JSON response.

The explicit GET status test:

    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/app/about

returned:

    200

Therefore the Stage 7 acceptance test uses a GET request.

The important successful test is:

    GET /api/app/about
    HTTP 200

---

# Why the HEAD Result Does Not Change the Stage 7 Result

The NGINX routing rule itself was confirmed using:

    /api

and:

    mealie:9000

The normal GET request successfully reached the application and returned the expected Mealie JSON response.

The explicit GET status test returned:

    200

Therefore the Ingress routing requirement is satisfied.

---

# Current Application Services

The Mealie application remains behind a ClusterIP Service:

    mealie
    Type: ClusterIP
    Port: 9000

PostgreSQL also remains behind a ClusterIP Service:

    postgres
    Type: ClusterIP
    Port: 5432

Neither application nor database requires a NodePort.

---

# Final Stage 7 Architecture

    ┌──────────────────────────────┐
    │          WSL Host            │
    │                              │
    │   curl localhost:8080        │
    └──────────────┬───────────────┘
                   |
                   | HTTP :8080
                   v
    ┌──────────────────────────────┐
    │        kind Cluster          │
    │                              │
    │      Node :80                │
    │         |                    │
    │         v                    │
    │  NGINX Ingress Controller    │
    │         |                    │
    │         v                    │
    │  Ingress /api                │
    │         |                    │
    │         v                    │
    │  Mealie ClusterIP :9000      │
    │         |                    │
    │         v                    │
    │  Mealie Pod :9000            │
    │         |                    │
    │         | postgres:5432      │
    │         v                    │
    │  PostgreSQL ClusterIP        │
    │         |                    │
    │         v                    │
    │  PostgreSQL Pod :5432        │
    │         |                    │
    │         v                    │
    │  PostgreSQL PVC              │
    └──────────────────────────────┘

---

# Stage 7 Verification

The following checks were successfully completed:

    ✓ Kubernetes cluster healthy
    ✓ Mealie Pod healthy
    ✓ PostgreSQL Pod healthy
    ✓ Mealie Service remains ClusterIP
    ✓ PostgreSQL Service remains ClusterIP
    ✓ NGINX Ingress Controller installed
    ✓ NGINX Controller Pod Running
    ✓ IngressClass nginx exists
    ✓ kind host port 8080 reaches kind port 80
    ✓ NGINX initially returned expected 404 without an Ingress rule
    ✓ Ingress resource created
    ✓ Ingress Class set to nginx
    ✓ /api path configured
    ✓ /api routes to mealie:9000
    ✓ /api/app/about returns Mealie JSON
    ✓ GET /api/app/about returns HTTP 200
    ✓ /not-api returns HTTP 404
    ✓ Mealie v3.22.0 confirmed

---

# Stage 7 Artifacts

The Stage 7 artifact is:

    stage-7-ingress/ingress.yaml

The existing Stage 3 kind configuration was reused because it already contained:

    hostPort: 8080
    containerPort: 80

No modification to:

    stage-3-kind-cluster/kind-cluster.yaml

was required.

---

# Important Security and Production Note

This Stage 7 implementation is a learning environment running on a local kind cluster.

It demonstrates the core Kubernetes Ingress concepts:

- HTTP routing
- Ingress Controllers
- ClusterIP Services
- Path-based routing
- kind port mappings
- Backend Service discovery

The local environment should not be treated as a production deployment.

Production environments would normally require additional considerations such as:

- TLS
- DNS
- Authentication
- Network policies
- Resource limits
- High availability
- Monitoring
- Logging
- Security controls
- Persistent storage strategy
- Ingress controller lifecycle and support

---

# NGINX Ingress Controller Project Status

This project uses NGINX Ingress specifically because Stage 7 is intended to teach the traditional Kubernetes Ingress architecture.

The Kubernetes ecosystem is increasingly moving toward Gateway API for newer traffic-management designs.

The NGINX Ingress implementation should therefore be understood as a learning milestone in this project rather than the final networking architecture.

---

# Lessons Learned

## Ingress

Ingress provides HTTP routing into Kubernetes Services.

## Ingress Controller

An Ingress resource alone does not process traffic.

An Ingress Controller watches Ingress resources and implements the routing.

## ClusterIP

ClusterIP provides the internal Service endpoint used by the Ingress backend.

## Path Routing

The Stage 7 rule routes:

    /api

to:

    mealie:9000

## Host Routing

Host routing can be used to route different domains to different Services.

It has not yet been implemented.

## Rewrite Rules

Rewrite rules are only necessary when the external URL path differs from the path expected by the backend application.

No rewrite was required in Stage 7.

## kind Port Mapping

The existing:

    8080 → 80

mapping allows HTTP traffic from the WSL host to reach the kind node and therefore the NGINX Ingress Controller.

---

# Stage 7 Result

Stage 7 successfully introduced NGINX Ingress into the local kind Kubernetes cluster.

The application is no longer exposed using NodePort.

The architecture is now:

    Client
       |
       v
    NGINX Ingress
       |
       v
    Mealie ClusterIP
       |
       v
    Mealie Pod
       |
       v
    PostgreSQL ClusterIP
       |
       v
    PostgreSQL Pod

The main application test:

    curl http://localhost:8080/api/app/about

returned the Mealie application response.

The explicit HTTP status test:

    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/app/about

returned:

    200

The unmatched path test:

    curl -I http://localhost:8080/not-api

returned:

    HTTP/1.1 404 Not Found

This confirms that NGINX Ingress is performing the intended path-based HTTP routing.

---

# Next Stage

## Stage 8 — Ingress Host-Based Routing and Rewrite Concepts

The next stage can build on the working Ingress architecture by introducing more advanced routing concepts.

Potential topics include:

- Host-based routing
- Multiple HTTP routes
- Path rewriting
- Ingress annotations
- DNS-style local hostnames
- Testing Host headers
- Routing multiple Services
- Understanding when rewrite rules are required
- Improving the Ingress configuration

Current Stage 7 routing:

    /api/* → mealie:9000

Stage 7 complete.
