Stage 9 — Argo CD (GitOps)

Overview

Stage 9 introduces Argo CD and GitOps into the Mealie Kubernetes project.

The goal is to move from manually deploying the Helm chart with Helm commands to having Argo CD continuously reconcile the Kubernetes environment from Git.

At the end of this stage:

Argo CD is installed in the cluster.

The Argo CD ApplicationSet controller is working.

Argo CD UI is accessible.

Mealie is deployed through an Argo CD Application.

Argo CD uses the Helm chart created in Stage 8.

The Git repository is the source of truth.

Automated sync is enabled.

Pruning is enabled.

Self-healing is enabled.

Mealie runs with two replicas in the GitOps environment.

PostgreSQL uses persistent storage.

The GitOps deployment is isolated in its own namespace.

1. Project Architecture

The project now follows this progression:

Stage 1
   ↓
Docker Compose
   ↓
Stage 3
   ↓
Kind Kubernetes Cluster
   ↓
Stage 4
   ↓
Kubernetes Deployments / Services / PVC / Secrets
   ↓
Stage 5
   ↓
Automation Scripts
   ↓
Stage 6
   ↓
ClusterIP Networking
   ↓
Stage 7
   ↓
NGINX Ingress
   ↓
Stage 8
   ↓
Helm
   ↓
Stage 9
   ↓
Argo CD / GitOps

2. GitOps Architecture

The Stage 9 environment works like this:

                    GitHub
                       │
                       │
             areghan/mealie-kubernetes
                       │
                       ▼
             stage-8-helm/mealie
                       │
                       ▼
                  Argo CD
                       │
                 Helm rendering
                       │
                       ▼
              Kubernetes Cluster
                       │
                       ▼
               mealie-gitops
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
        Mealie App          PostgreSQL
        2 replicas           1 replica
              │                 │
              │                 ▼
              │          PersistentVolumeClaim
              │
              ▼
         Kubernetes Service

The important GitOps principle is:

Git
 ↓
Argo CD
 ↓
Kubernetes

Instead of manually changing Kubernetes resources, changes should eventually be made in Git and Argo CD should reconcile them into the cluster.

3. Current Environment

Kubernetes

Cluster:

mealie-cluster

Context:

kind-mealie-cluster

Kubernetes version:

v1.36.1

Existing namespaces

The project uses:

mealie
argocd
mealie-gitops

The original mealie namespace is used by the manually installed Helm deployment from Stage 8.

The new mealie-gitops namespace is used by Argo CD.

This separation prevents Helm and Argo CD from trying to manage the same Kubernetes resources.

4. Why a Separate GitOps Namespace Was Used

Stage 8 already had a Helm release installed manually:

mealie

Rather than immediately removing the existing Helm deployment, Stage 9 creates:

mealie-gitops

This means:

Stage 8 Helm deployment
        │
        ▼
     mealie

and:

Stage 9 Argo CD deployment
        │
        ▼
  mealie-gitops

Both can exist at the same time while the GitOps workflow is learned.

This is useful for learning because it avoids accidentally uninstalling the Stage 8 release or deleting its PostgreSQL resources.

5. Install Argo CD

Argo CD is installed into the argocd namespace.

First create the namespace:

kubectl create namespace argocd

If the namespace already exists, Kubernetes may report:

Error from server (AlreadyExists)

That is fine.

Check:

kubectl get namespace argocd

Install Argo CD

For a clean installation, server-side apply can be used:

kubectl apply -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Wait for the pods:

kubectl get pods -n argocd

6. ApplicationSet CRD Issue

During this installation, the ApplicationSet controller initially failed because the ApplicationSet CRD was not available.

The error was similar to:

failed to get restmapping: no matches for kind "ApplicationSet" in version "argoproj.io/v1alpha1"

The initially installed Argo CD CRDs included:

applications.argoproj.io
appprojects.argoproj.io

but the ApplicationSet CRD was missing.

7. Fix the ApplicationSet CRD

Install the ApplicationSet CRD using server-side apply:

kubectl apply -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/crds/applicationset-crd.yaml

Restart the ApplicationSet controller:

kubectl rollout restart deployment argocd-applicationset-controller -n argocd

Check the pods:

kubectl get pods -n argocd

All Argo CD components should eventually show:

1/1 Running

8. Verify Argo CD Components

Run:

kubectl get pods -n argocd

Expected components include:

argocd-application-controller
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server

The exact pod names will contain generated suffixes.

Check services:

kubectl get svc -n argocd

The Argo CD server should exist:

argocd-server

9. Access the Argo CD Web UI

The Argo CD server is exposed internally as a ClusterIP service.

Check:

kubectl get svc argocd-server -n argocd

The service uses:

80/TCP
443/TCP

The Kind cluster already uses port 8080 for the NGINX ingress setup, so Argo CD will use port 8443 locally.

Run:

kubectl port-forward svc/argocd-server -n argocd 8443:443

Keep this terminal running.

Then open:

https://localhost:8443

Your browser may show a certificate warning because this is a local Argo CD HTTPS endpoint.

10. Get the Initial Admin Password

Run:

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

The username is:

admin

The password is the value returned by the command.

Use those credentials to log into the Argo CD UI.

11. Create the GitOps Namespace

Create:

mealie-gitops

Command:

kubectl create namespace mealie-gitops

Verify:

kubectl get namespace mealie-gitops

12. Namespace Manifest

The namespace is also represented as Kubernetes configuration.

File:

stage-9-argocd/manifests/namespace.yaml

Contents:

apiVersion: v1
kind: Namespace
metadata:
  name: mealie-gitops

Apply it with:

kubectl apply -f stage-9-argocd/manifests/namespace.yaml

13. Argo CD Application

The main GitOps object is the Argo CD Application.

File:

stage-9-argocd/argocd/application.yaml

Contents:

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mealie-gitops
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/areghan/mealie-kubernetes.git
    targetRevision: main
    path: stage-8-helm/mealie

    helm:
      values: |
        namespace: mealie-gitops

        mealie:
          replicaCount: 2

          ingress:
            enabled: false

  destination:
    server: https://kubernetes.default.svc
    namespace: mealie-gitops

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

14. Apply the Argo CD Application

Run:

kubectl apply -f stage-9-argocd/argocd/application.yaml

Expected result:

application.argoproj.io/mealie-gitops created

If it already exists:

application.argoproj.io/mealie-gitops configured

15. Check the Argo CD Application

Run:

kubectl get applications -n argocd

Expected:

NAME            SYNC STATUS   HEALTH STATUS
mealie-gitops   Synced        Healthy

You can also run:

kubectl get application mealie-gitops -n argocd

16. Inspect the Application

Run:

kubectl describe application mealie-gitops -n argocd

This shows:

Git repository

Git revision

Helm configuration

destination namespace

sync policy

resources

health

sync status

17. Git Repository Used by Argo CD

Argo CD watches:

https://github.com/areghan/mealie-kubernetes.git

Branch:

main

The Helm chart path is:

stage-8-helm/mealie

Therefore Argo CD uses:

GitHub
   │
   ▼
stage-8-helm/mealie
   │
   ▼
Helm chart
   │
   ▼
Kubernetes resources

18. Why Stage 8 Is Used by Stage 9

Stage 8 created the Helm chart.

The chart contains:

stage-8-helm/
└── mealie/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── _helpers.tpl
        ├── configmap.yaml
        ├── deployment.yaml
        ├── ingress.yaml
        ├── pvc.yaml
        ├── secret.yaml
        └── service.yaml

Stage 9 does not create another Helm chart.

Instead:

Argo CD
   ↓
loads Stage 8 Helm chart
   ↓
renders Helm templates
   ↓
applies resources to Kubernetes

This demonstrates how Helm and Argo CD work together.

19. Helm Values Used by Argo CD

The Argo CD Application overrides some Helm values.

The important values are:

namespace: mealie-gitops

mealie:
  replicaCount: 2

  ingress:
    enabled: false

This means the GitOps deployment:

runs in mealie-gitops

runs two Mealie replicas

does not create another ingress

The ingress is disabled because Stage 9 is focused on GitOps rather than creating another external ingress route.

20. Why replicaCount Uses camelCase

The Helm chart defines:

mealie:
  replicaCount: 1

Therefore the Argo CD override must use:

replicaCount: 2

Not:

replica-count: 2

Helm values are case-sensitive and name-sensitive.

Using:

replica-count

would create a value that the chart does not use.

21. Automated Sync

The Application contains:

syncPolicy:
  automated:
    prune: true
    selfHeal: true

This enables automated reconciliation.

Automated sync

The automated configuration allows Argo CD to automatically synchronize desired state from Git.

Prune

prune: true

allows Argo CD to remove resources that are no longer part of the desired application.

Self-healing

selfHeal: true

allows Argo CD to detect drift between the desired configuration and the live Kubernetes resources and attempt to restore the desired state.

22. Check Sync Status

Run:

kubectl get application mealie-gitops -n argocd

Expected:

NAME            SYNC STATUS   HEALTH STATUS
mealie-gitops   Synced        Healthy

Another useful command:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.sync.status}{"\n"}'

Expected:

Synced

Check health:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.health.status}{"\n"}'

Expected:

Healthy

23. Check Git Revision

Run:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.sync.revision}{"\n"}'

This shows the Git commit Argo CD has synchronized.

24. Check GitOps Resources

Run:

kubectl get all -n mealie-gitops

Expected resources include:

deployment.apps/mealie-gitops-app
deployment.apps/mealie-gitops-postgres

service/mealie-gitops-app
service/mealie-gitops-postgres

pod/mealie-gitops-app-...
pod/mealie-gitops-app-...
pod/mealie-gitops-postgres-...

25. Check Deployments

Run:

kubectl get deployments -n mealie-gitops

Expected:

NAME                    READY   UP-TO-DATE   AVAILABLE
mealie-gitops-app       2/2     2            2
mealie-gitops-postgres  1/1     1            1

The Mealie deployment has:

2 replicas

The PostgreSQL deployment has:

1 replica

26. Check Pods

Run:

kubectl get pods -n mealie-gitops

Expected:

mealie-gitops-app-...        1/1   Running
mealie-gitops-app-...        1/1   Running
mealie-gitops-postgres-...   1/1   Running

27. Check Services

Run:

kubectl get svc -n mealie-gitops

Expected services:

mealie-gitops-app
mealie-gitops-postgres

Mealie:

9000/TCP

PostgreSQL:

5432/TCP

Both are ClusterIP services.

28. Check Persistent Storage

Run:

kubectl get pvc -n mealie-gitops

Expected:

mealie-gitops-postgres-pvc

Status should be:

Bound

The PVC is:

5Gi
ReadWriteOnce

PostgreSQL therefore has persistent storage rather than relying only on ephemeral container storage.

29. Test Mealie Internally

The GitOps Mealie service is:

mealie-gitops-app

Run:

kubectl run mealie-gitops-test \
  -n mealie-gitops \
  --rm \
  --stdin \
  --tty=false \
  --restart=Never \
  --image=curlimages/curl:8.10.1 \
  -- curl --fail --silent --show-error \
  http://mealie-gitops-app:9000/api/app/about

A successful response should return Mealie application information as JSON.

30. Why Ingress Is Disabled for Stage 9

Stage 8 already demonstrated NGINX ingress.

Stage 9 is focused on:

Git
 ↓
Argo CD
 ↓
Helm
 ↓
Kubernetes

Therefore the Argo-managed application has:

ingress:
  enabled: false

This avoids introducing another ingress route while learning GitOps.

The existing Stage 8 deployment can still be accessed separately.

31. Scaling the GitOps Deployment

The desired state is:

mealie:
  replicaCount: 2

Check:

kubectl get deployment mealie-gitops-app -n mealie-gitops

Expected:

READY
2/2

Check the pods:

kubectl get pods -n mealie-gitops

There should be two Mealie application pods.

32. Important GitOps Lesson — Application Definition vs Application Source

One important lesson from Stage 9 was discovered while changing the replica count.

The Argo CD Application watches:

stage-8-helm/mealie

It does NOT automatically watch:

stage-9-argocd/argocd/application.yaml

just because that file exists in the same Git repository.

The Application object itself was created manually with:

kubectl apply -f stage-9-argocd/argocd/application.yaml

Therefore, changing that YAML file in Git does not automatically update the existing Application object unless another Argo CD Application is managing that file.

This is an important GitOps concept.

33. What Happened When replicaCount Was Changed

The Application was initially configured with:

mealie:
  replicaCount: 1

The value was changed to:

mealie:
  replicaCount: 2

and committed to Git.

Argo CD detected the new Git revision, but the live Application configuration still contained the old Helm values.

The Application definition therefore had to be applied again:

kubectl apply -f stage-9-argocd/argocd/application.yaml

After the Application object was updated, Argo CD reconciled the Helm deployment and changed the number of replicas to:

2

This demonstrates the difference between:

The Git repository contains an Application YAML

and:

Argo CD is actually managing that Application YAML

A future stage could make the Argo CD Application itself GitOps-managed.

34. Verify Current Application Configuration

Run:

kubectl get application mealie-gitops -n argocd -o yaml

Look for:

helm:
  values: |
    namespace: mealie-gitops

    mealie:
      replicaCount: 2

      ingress:
        enabled: false

35. Check Argo CD Resource Tree

From the Argo CD UI, select:

mealie-gitops

The application should show:

Synced
Healthy

The resource tree should contain resources for:

Deployment
Service
ConfigMap
Secret
PersistentVolumeClaim

The two Mealie pods should be visible under the application deployment.

36. Useful Argo CD Commands

List Applications:

kubectl get applications -n argocd

Describe Application:

kubectl describe application mealie-gitops -n argocd

Get Application YAML:

kubectl get application mealie-gitops -n argocd -o yaml

Get sync status:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.sync.status}{"\n"}'

Get health:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.health.status}{"\n"}'

Get Git revision:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.sync.revision}{"\n"}'

37. Useful Kubernetes Verification Commands

Check all GitOps resources:

kubectl get all -n mealie-gitops

Check pods:

kubectl get pods -n mealie-gitops

Check deployments:

kubectl get deployments -n mealie-gitops

Check services:

kubectl get svc -n mealie-gitops

Check PVC:

kubectl get pvc -n mealie-gitops

Check ConfigMaps:

kubectl get configmaps -n mealie-gitops

Check Secrets:

kubectl get secrets -n mealie-gitops

38. Check Argo CD Logs

If something goes wrong, check the application controller:

kubectl logs \
  -n argocd \
  deployment/argocd-application-controller

Check the repo server:

kubectl logs \
  -n argocd \
  deployment/argocd-repo-server

Check the ApplicationSet controller:

kubectl logs \
  -n argocd \
  deployment/argocd-applicationset-controller

39. Check the Git Repository

From the project directory:

cd ~/mealie-projects

Check Git status:

git status

Check recent commits:

git log --oneline --decorate -10

Check remote:

git remote -v

Expected GitHub repository:

github.com:areghan/mealie-kubernetes.git

40. Stage 9 Files

The Stage 9 directory contains:

stage-9-argocd/
├── README.md
├── argocd/
│   └── application.yaml
└── manifests/
    └── namespace.yaml

The README contains the complete Stage 9 documentation.

The Kubernetes manifests remain separate so they can also be applied directly with kubectl.

41. Add Stage 9 Files to Git

Run:

git add stage-9-argocd/

Check:

git status

You should see the Stage 9 files staged.

42. Commit Stage 9

Use:

git commit -m "Add Stage 9 Argo CD GitOps"

Then push:

git push origin main

43. Verify GitHub

After pushing:

git log --oneline --decorate -5

The latest commit should contain:

Add Stage 9 Argo CD GitOps

The GitHub repository should now contain:

stage-9-argocd/

44. Current GitOps State

The final Stage 9 architecture is:

GitHub
  │
  │ main
  ▼
stage-8-helm/mealie
  │
  │
  ▼
Argo CD Application
  │
  │
  ├── Automated Sync
  ├── Prune
  └── Self Heal
  │
  ▼
mealie-gitops namespace
  │
  ├── Mealie Deployment
  │      └── 2 replicas
  │
  ├── PostgreSQL Deployment
  │      └── 1 replica
  │
  ├── Mealie Service
  │
  ├── PostgreSQL Service
  │
  ├── ConfigMap
  │
  ├── Secret
  │
  └── PostgreSQL PVC

45. Final Verification Checklist

Run:

kubectl get pods -n argocd

All important Argo CD pods should be:

Running

Run:

kubectl get application mealie-gitops -n argocd

Expected:

Synced
Healthy

Run:

kubectl get pods -n mealie-gitops

Expected:

2 Mealie pods
1 PostgreSQL pod

Run:

kubectl get deployment -n mealie-gitops

Expected:

mealie-gitops-app       2/2
mealie-gitops-postgres  1/1

Run:

kubectl get pvc -n mealie-gitops

Expected:

Bound

Run:

kubectl get svc -n mealie-gitops

Expected:

mealie-gitops-app
mealie-gitops-postgres

Run:

kubectl get application mealie-gitops -n argocd \
  -o jsonpath='{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'

Expected:

Synced
Healthy

46. Stage 9 Outcome

Stage 9 introduced GitOps into the Mealie Kubernetes project.

The major concepts learned were:

Installing Argo CD.

Understanding the Argo CD control plane.

Working with Argo CD CRDs.

Fixing the ApplicationSet CRD installation issue.

Accessing the Argo CD UI.

Creating an Argo CD Application.

Connecting Argo CD to GitHub.

Using an existing Helm chart as the Argo CD source.

Overriding Helm values from the Argo CD Application.

Deploying into a separate namespace.

Enabling automated synchronization.

Enabling pruning.

Enabling self-healing.

Verifying application health.

Verifying Git revision.

Scaling the application through Helm values.

Understanding the difference between an Application definition and the application's watched source.

Understanding the basic Git → Argo CD → Kubernetes GitOps workflow.

The project has now progressed from:

Docker Compose

to:

Kubernetes

to:

Helm

to:

GitOps with Argo CD

47. Final Stage 9 Status

Stage 9 — COMPLETE

Current state:

Argo CD
    │
    ├── Installed
    ├── UI accessible
    ├── ApplicationSet controller working
    └── Application configured
            │
            ▼
        GitHub
            │
            ▼
      Helm Chart
            │
            ▼
    mealie-gitops namespace
            │
       ┌────┴────┐
       ▼         ▼
    Mealie    PostgreSQL
    2 pods       1 pod
       │           │
       │           ▼
       │       5Gi PVC
       │
       ▼
    Healthy

Argo CD Application:

mealie-gitops

Sync status:

Synced

Health status:

Healthy

Mealie replicas:

2

PostgreSQL replicas:

1

Git branch:

main

GitOps namespace:

mealie-gitops

48. Key GitOps Principle

The most important lesson from this stage is:

Git is the desired state.
Argo CD continuously reconciles desired state with Kubernetes.
Kubernetes runs the resulting workloads.

The intended workflow going forward is:

Developer
    │
    ▼
Edit Git
    │
    ▼
Commit
    │
    ▼
Push to GitHub
    │
    ▼
Argo CD detects desired-state changes
    │
    ▼
Argo CD reconciles Kubernetes
    │
    ▼
Application changes

This is the foundation for the next stages of the project.
