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
