# Stage 8 — Helm: Chart Creation

## Goal

Stop copy-pasting Kubernetes YAML and package the Mealie application and PostgreSQL deployment into a reusable Helm chart.

This stage introduces:

* Helm installation and verification
* Helm chart structure
* `Chart.yaml`
* `values.yaml`
* Helm templates
* Deployment templates
* Service templates
* ConfigMap template
* Secret template
* PVC template
* Ingress template
* `helm lint`
* `helm template`
* `helm install`
* `helm upgrade`
* Helm release revisions
* Helm resource ownership
* Ingress rewrite rules
* Reusing configuration through Helm values

---

# 1. Prerequisites

The project already contains the Kubernetes infrastructure built during previous stages.

The project structure includes:

```text
mealie-projects/
├── stage-0-workstation/
├── stage-1-mealie/
├── stage-3-kind-cluster/
├── stage-4-kubernetes-basics/
├── stage-5-scripts-automation/
├── stage-6-clusterip/
├── stage-7-ingress/
└── stage-8-helm/
    └── mealie/
```

Helm was installed and verified with:

```bash
helm version
```

Output:

```text
version.BuildInfo{Version:"v3.21.3", GitCommit:"1ad6e68924fdf6fb0c7dcef8e9e1dfc0f36eaed6", GitTreeState:"clean", GoVersion:"go1.26.5"}
```

---

# 2. Why Helm?

Before Helm, Kubernetes resources were managed using individual YAML files.

For example:

```text
namespace.yaml
postgres-secret.yaml
postgres-pvc.yaml
postgres-deployment.yaml
postgres-service.yaml
mealie-deployment.yaml
mealie-service.yaml
ingress.yaml
```

This works, but it becomes difficult to maintain as applications become more complicated.

Helm packages Kubernetes resources into a reusable chart.

Instead of manually changing multiple YAML files, configuration can be centralized in:

```text
values.yaml
```

Templates then consume those values.

The basic model becomes:

```text
values.yaml
      |
      v
Helm Templates
      |
      v
Rendered Kubernetes YAML
      |
      v
Kubernetes
```

---

# 3. Helm Chart Structure

The Stage 8 chart has the following structure:

```text
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
```

The chart can be inspected with:

```bash
tree
```

---

# 4. Chart.yaml

The chart metadata is:

```yaml
apiVersion: v2
name: mealie
description: Helm chart for Mealie and PostgreSQL on Kubernetes
type: application
version: 0.1.0
appVersion: "v3.22.0"
```

The chart uses:

```text
apiVersion: v2
```

because this is a Helm 3 chart.

The chart version is:

```text
0.1.0
```

The application version is:

```text
v3.22.0
```

---

# 5. values.yaml

The main configuration is stored in `values.yaml`.

```yaml
namespace: mealie

mealie:
  replicaCount: 1

  image:
    repository: ghcr.io/mealie-recipes/mealie
    tag: v3.22.0
    pullPolicy: IfNotPresent

  service:
    type: ClusterIP
    port: 9000
    targetPort: 9000

  ingress:
    enabled: true
    className: nginx
    path: /helm-api
    pathType: Prefix

postgres:
  replicaCount: 1

  image:
    repository: postgres
    tag: "17"
    pullPolicy: IfNotPresent

  service:
    port: 5432
    targetPort: 5432

  persistence:
    enabled: true
    existingClaim: ""
    size: 5Gi
    accessMode: ReadWriteOnce

  database:
    user: mealie
    password: mealie
    name: mealie
```

The chart uses `values.yaml` so that configuration can be changed without modifying every Kubernetes template.

For example:

```yaml
mealie:
  image:
    tag: v3.22.0
```

controls the Mealie image version.

The Service is configured as:

```yaml
service:
  type: ClusterIP
```

because NodePort was removed in Stage 6 in preparation for Ingress.

---

# 6. Helper Template

The `_helpers.tpl` file provides reusable Helm template helpers.

The chart uses:

```text
mealie.fullname
```

to generate consistent resource names.

This allows templates to use expressions such as:

```yaml
name: {{ include "mealie.fullname" . }}-app
```

instead of hard-coding names.

---

# 7. ConfigMap Template

The ConfigMap provides non-sensitive application configuration.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mealie.fullname" . }}-config
  namespace: {{ .Values.namespace }}
data:
  DB_ENGINE: "postgres"
  POSTGRES_SERVER: "{{ include "mealie.fullname" . }}-postgres"
  POSTGRES_PORT: "5432"
```

The important configuration is:

```text
POSTGRES_SERVER
```

which points Mealie at the Helm-managed PostgreSQL Service.

The rendered value is:

```text
mealie-postgres
```

---

# 8. Secret Template

The PostgreSQL credentials are stored in a Kubernetes Secret.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mealie.fullname" . }}-postgres-secret
  namespace: {{ .Values.namespace }}
type: Opaque
stringData:
  POSTGRES_USER: "{{ .Values.postgres.database.user }}"
  POSTGRES_PASSWORD: "{{ .Values.postgres.database.password }}"
  POSTGRES_DB: "{{ .Values.postgres.database.name }}"
```

The values come from:

```yaml
postgres:
  database:
    user: mealie
    password: mealie
    name: mealie
```

For a real production deployment, credentials should be handled more securely rather than storing real passwords directly in a Git repository.

---

# 9. PVC Template

The PostgreSQL database requires persistent storage.

The chart creates:

```text
mealie-postgres-pvc
```

when an existing claim is not supplied.

```yaml
{{- if and .Values.postgres.persistence.enabled (not .Values.postgres.persistence.existingClaim) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "mealie.fullname" . }}-postgres-pvc
  namespace: {{ .Values.namespace }}
spec:
  accessModes:
    - {{ .Values.postgres.persistence.accessMode }}

  resources:
    requests:
      storage: {{ .Values.postgres.persistence.size }}
{{- end }}
```

For Stage 8, the chart uses:

```yaml
existingClaim: ""
```

so Helm creates its own PVC.

This was intentional because the existing Stage 7 PostgreSQL instance was already using:

```text
postgres-pvc
```

Running another PostgreSQL instance against the same `ReadWriteOnce` PVC would not be safe.

The Helm deployment therefore has its own:

```text
mealie-postgres-pvc
```

while the Stage 7 environment retains:

```text
postgres-pvc
```

---

# 10. Service Templates

The chart creates two ClusterIP Services.

## PostgreSQL Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mealie.fullname" . }}-postgres
  namespace: {{ .Values.namespace }}
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
    - protocol: TCP
      port: {{ .Values.postgres.service.port }}
      targetPort: {{ .Values.postgres.service.targetPort }}
```

The rendered Service is:

```text
mealie-postgres
```

and listens on:

```text
5432
```

## Mealie Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mealie.fullname" . }}-app
  namespace: {{ .Values.namespace }}
spec:
  type: {{ .Values.mealie.service.type }}
  selector:
    app: mealie
  ports:
    - protocol: TCP
      port: {{ .Values.mealie.service.port }}
      targetPort: {{ .Values.mealie.service.targetPort }}
```

The rendered Service is:

```text
mealie-app
```

and listens on:

```text
9000
```

Both Services are:

```text
ClusterIP
```

---

# 11. PostgreSQL Deployment

The PostgreSQL Deployment uses:

```text
postgres:17
```

and the Helm-created PVC.

The important volume configuration is:

```yaml
volumes:
  - name: postgres-storage
    persistentVolumeClaim:
      claimName: {{ default (printf "%s-postgres-pvc" (include "mealie.fullname" .)) .Values.postgres.persistence.existingClaim }}
```

With the Stage 8 values, this renders as:

```yaml
claimName: mealie-postgres-pvc
```

The Deployment is named:

```text
mealie-postgres
```

---

# 12. Mealie Deployment

The Mealie Deployment uses:

```text
ghcr.io/mealie-recipes/mealie:v3.22.0
```

The rendered Deployment name is:

```text
mealie-app
```

The container listens on:

```text
9000
```

The Deployment imports configuration from:

```text
mealie-config
```

and:

```text
mealie-postgres-secret
```

The Pod is labelled:

```yaml
app: mealie
```

This allows the Service to select the correct Pods.

---

# 13. Ingress Template

The Helm chart also manages an NGINX Ingress.

```yaml
{{- if .Values.mealie.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mealie.fullname" . }}-ingress
  namespace: {{ .Values.namespace }}
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /api/$2
spec:
  ingressClassName: {{ .Values.mealie.ingress.className }}

  rules:
    - http:
        paths:
          - path: /helm-api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: {{ include "mealie.fullname" . }}-app
                port:
                  number: {{ .Values.mealie.service.port }}
{{- end }}
```

The rendered Ingress is:

```text
mealie-ingress
```

---

# 14. Why the Ingress Uses a Rewrite

Mealie's API endpoint is:

```text
/api/app/about
```

During Stage 7, `/api` was already being used by the original manually-created Ingress.

The Helm deployment was intentionally tested alongside the Stage 7 deployment.

Therefore, the Helm Ingress uses:

```text
/helm-api
```

instead.

The NGINX rewrite converts:

```text
/helm-api/app/about
```

into:

```text
/api/app/about
```

using:

```yaml
nginx.ingress.kubernetes.io/rewrite-target: /api/$2
```

and:

```yaml
nginx.ingress.kubernetes.io/use-regex: "true"
```

The resulting flow is:

```text
localhost:8080/helm-api/app/about
                |
                v
        NGINX Ingress
                |
                v
          rewrite request
                |
                v
        /api/app/about
                |
                v
        mealie-app:9000
                |
                v
           Mealie
```

---

# 15. Helm Lint

Before installing the chart, it was validated with:

```bash
helm lint .
```

The result was:

```text
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

The icon message is informational and does not indicate a chart failure.

---

# 16. Helm Template

The chart was rendered without installing it using:

```bash
helm template mealie .
```

This confirmed that Helm could successfully render:

```text
Secret
ConfigMap
PersistentVolumeClaim
Service
Service
Deployment
Deployment
Ingress
```

The final resource names were:

```text
mealie-postgres-secret
mealie-config
mealie-postgres-pvc
mealie-postgres
mealie-app
mealie-postgres
mealie-app
mealie-ingress
```

The rendered PostgreSQL claim was:

```text
mealie-postgres-pvc
```

and the PostgreSQL Deployment referenced:

```text
claimName: mealie-postgres-pvc
```

---

# 17. Helm Resource Ownership

The first installation attempt encountered existing Kubernetes resources from previous stages.

Helm requires resources that it adopts to contain the correct ownership metadata.

The intended Helm release was:

```text
release-name: mealie
release-namespace: mealie
```

Some existing resources initially contained:

```text
release-namespace: default
```

These resources were corrected so that Helm could manage them in the intended namespace.

The existing Stage 7 PostgreSQL PVC:

```text
postgres-pvc
```

was preserved.

The Helm deployment uses its own PVC:

```text
mealie-postgres-pvc
```

This keeps the Stage 7 and Stage 8 PostgreSQL deployments separated.

---

# 18. Helm Install

After the resource ownership and naming issues were resolved, the chart was installed using:

```bash
helm install mealie . -n mealie
```

The successful installation reported:

```text
NAME: mealie
NAMESPACE: mealie
STATUS: deployed
REVISION: 1
```

---

# 19. Helm Release

The release was verified with:

```bash
helm list -n mealie
```

The final release is:

```text
NAME    NAMESPACE   REVISION    STATUS
mealie  mealie      2           deployed
```

The chart is:

```text
mealie-0.1.0
```

and the application version is:

```text
v3.22.0
```

---

# 20. Helm Upgrade

The Ingress initially returned:

```text
404
```

for:

```text
/helm-api/app/about
```

The reason was that the path needed to be rewritten to Mealie's actual `/api` endpoint.

The Ingress template was updated with:

```yaml
nginx.ingress.kubernetes.io/use-regex: "true"
nginx.ingress.kubernetes.io/rewrite-target: /api/$2
```

The chart was then upgraded using:

```bash
helm upgrade mealie . -n mealie
```

The result was:

```text
Release "mealie" has been upgraded. Happy Helming!
NAME: mealie
NAMESPACE: mealie
STATUS: deployed
REVISION: 2
```

This demonstrated the difference between:

```text
helm install
```

and:

```text
helm upgrade
```

The initial installation created:

```text
Revision 1
```

The configuration change produced:

```text
Revision 2
```

---

# 21. Final Helm Status

The final command:

```bash
helm status mealie -n mealie
```

returned:

```text
NAME: mealie
NAMESPACE: mealie
STATUS: deployed
REVISION: 2
```

This confirms that the Helm release is healthy.

---

# 22. Final Kubernetes Resources

The final Kubernetes resources were checked with:

```bash
kubectl get pods,svc,pvc,ingress -n mealie
```

The Helm-managed Pods were:

```text
mealie-app-7cc7647879-kkr5c
mealie-postgres-6cfb8fd8b9-kjb77
```

Both were:

```text
1/1 Running
```

The original Stage 7 Pods were also still running:

```text
mealie-54f9577854-zp7kt
postgres-6bd965bdb7-9q2cq
```

This demonstrated that the Helm deployment could coexist with the previous manually-managed deployment.

---

# 23. Services

The final Services included:

```text
mealie
mealie-app
mealie-postgres
postgres
```

The Helm Services were:

```text
mealie-app
mealie-postgres
```

Both were:

```text
ClusterIP
```

No NodePort was required for the Helm deployment.

Traffic is intended to enter through NGINX Ingress.

---

# 24. Persistent Volumes

The final PVCs were:

```text
mealie-postgres-pvc
postgres-pvc
```

The original Stage 7 database continued using:

```text
postgres-pvc
```

The Helm-managed PostgreSQL deployment used:

```text
mealie-postgres-pvc
```

Both PVCs were:

```text
Bound
```

with:

```text
5Gi
ReadWriteOnce
standard
```

---

# 25. Ingress

The namespace contains two Ingress resources:

```text
mealie
mealie-ingress
```

The original Stage 7 Ingress handles:

```text
/api
```

The Helm-managed Ingress handles:

```text
/helm-api
```

This separation avoids an NGINX routing conflict while both deployments are running.

---

# 26. Helm Manifest Verification

The resources managed by the Helm release were verified using:

```bash
helm get manifest mealie -n mealie | grep -E "^(kind:|  name:)"
```

The result was:

```text
kind: Secret
  name: mealie-postgres-secret

kind: ConfigMap
  name: mealie-config

kind: PersistentVolumeClaim
  name: mealie-postgres-pvc

kind: Service
  name: mealie-postgres

kind: Service
  name: mealie-app

kind: Deployment
  name: mealie-postgres

kind: Deployment
  name: mealie-app

kind: Ingress
  name: mealie-ingress
```

This confirms that Helm manages the complete Stage 8 application stack.

---

# 27. Internal Application Test

The Helm-managed Mealie Service was tested from inside the Kubernetes cluster.

Command:

```bash
kubectl run mealie-helm-test \
  -n mealie \
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
  http://mealie-app:9000/api/app/about
```

The application responded successfully:

```json
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
  "tokenTime": 48
}
```

This proves that:

```text
Mealie Pod
    |
    v
mealie-app Service
    |
    v
Mealie API
```

is working.

---

# 28. Final Ingress Test

The Helm Ingress was tested with:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:8080/helm-api/app/about
```

The final result was:

```text
200
```

The complete response was:

```bash
curl http://localhost:8080/helm-api/app/about
```

Response:

```json
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
```

This proves the complete HTTP path:

```text
localhost:8080
      |
      v
NGINX Ingress
      |
      v
/helm-api/app/about
      |
      v
rewrite to /api/app/about
      |
      v
mealie-app:9000
      |
      v
Mealie v3.22.0
```

---

# 29. What Stage 8 Demonstrated

Stage 8 successfully demonstrated how Helm replaces manually maintained Kubernetes YAML with a reusable chart.

The final workflow is:

```text
Chart.yaml
    |
    v
values.yaml
    |
    v
Helm Templates
    |
    v
helm lint
    |
    v
helm template
    |
    v
helm install
    |
    v
Revision 1
    |
    v
Change configuration
    |
    v
helm upgrade
    |
    v
Revision 2
    |
    v
Verified application
```

The chart now manages:

```text
Secret
ConfigMap
PVC
PostgreSQL Deployment
PostgreSQL Service
Mealie Deployment
Mealie Service
Ingress
```

---

# 30. Useful Helm Commands

Check Helm releases:

```bash
helm list -n mealie
```

Check release status:

```bash
helm status mealie -n mealie
```

Validate chart:

```bash
helm lint .
```

Render chart without installing:

```bash
helm template mealie .
```

Install chart:

```bash
helm install mealie . -n mealie
```

Upgrade chart:

```bash
helm upgrade mealie . -n mealie
```

View rendered Kubernetes resources managed by Helm:

```bash
helm get manifest mealie -n mealie
```

View release history:

```bash
helm history mealie -n mealie
```

---

# 31. Final Stage 8 Status

Stage 8 is complete.

Validated:

```text
✓ Helm installed
✓ Chart created
✓ Chart.yaml configured
✓ values.yaml configured
✓ Helper template configured
✓ ConfigMap template
✓ Secret template
✓ PVC template
✓ PostgreSQL Deployment template
✓ Mealie Deployment template
✓ PostgreSQL Service template
✓ Mealie Service template
✓ Ingress template
✓ Helm lint passed
✓ Helm template passed
✓ Helm install succeeded
✓ Helm upgrade succeeded
✓ Helm Revision 2 deployed
✓ PostgreSQL Pod running
✓ Mealie Pod running
✓ PostgreSQL PVC Bound
✓ Mealie Service working
✓ PostgreSQL Service working
✓ Internal API test passed
✓ NGINX Ingress test passed
✓ HTTP 200 returned from Helm-managed Ingress
✓ No NodePort required
✓ Existing Stage 7 resources preserved
```

The Helm-managed application is now successfully running alongside the previous Kubernetes deployment.

---

# End of Stage 8

