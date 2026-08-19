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
