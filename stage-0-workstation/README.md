# Stage 0 — Workstation Setup

## Goal

Build and verify a clean Linux development environment capable of running Docker and local Kubernetes workloads.

This stage focuses only on the workstation and tooling. No Kubernetes cluster is created during this stage.

## Environment

* Windows
* WSL2
* Ubuntu 22.04.5 LTS
* Docker Desktop
* Docker Engine 29.6.1
* kubectl v1.36.1
* kind v0.33.0-alpha

## Directory Structure

```text
~/mealie-projects/
└── stage-0-workstation/
    └── README.md
```

## Components

### WSL2

WSL2 provides the Linux environment used for the project.

Verified with:

```bash
uname -a
```

The output confirmed the Microsoft WSL2 kernel:

```text
6.18.33.2-microsoft-standard-WSL2
```

### Ubuntu

Operating system:

```text
Ubuntu 22.04.5 LTS
Codename: jammy
```

Verified with:

```bash
cat /etc/os-release
```

### Docker

Docker Desktop is integrated with the Ubuntu WSL2 environment.

Docker version:

```text
Docker 29.6.1
```

Verified with:

```bash
docker --version
docker info
```

Docker functionality was tested successfully with:

```bash
docker run --rm hello-world
```

The test confirmed that:

* The Docker client can communicate with the Docker daemon.
* Docker can pull images from Docker Hub.
* Docker can create containers.
* Containers can execute successfully.

### Docker Compose

Docker Compose is available through the Docker CLI.

Verified with:

```bash
docker compose version
```

Version:

```text
Docker Compose v5.1.4
```

### kubectl

The Kubernetes command-line tool is installed and available.

Verified with:

```bash
kubectl version --client
```

Version:

```text
v1.36.1
```

Kustomize version:

```text
v5.8.1
```

No Kubernetes cluster was created during Stage 0.

### kind

kind is installed and available for creating local Kubernetes clusters.

Verified with:

```bash
kind version
```

Version:

```text
v0.33.0-alpha
```

No kind cluster was created during Stage 0.

## Verification

The following tools were successfully verified:

```text
WSL2                 ✅
Ubuntu 22.04.5 LTS   ✅
Docker                ✅
Docker Compose        ✅
kubectl               ✅
kind                   ✅
Project directory     ✅
```

## Stage 0 Completion Criteria

Stage 0 is complete when:

1. WSL2 is running successfully.
2. Ubuntu is running under WSL2.
3. Docker Desktop is integrated with WSL2.
4. Docker can successfully run a container.
5. Docker Compose is available.
6. kubectl is installed.
7. kind is installed.
8. The project directory has been created.
9. No Kubernetes cluster has been created yet.

## Result

Stage 0 completed successfully.

The workstation is ready for the next stages of the Mealie Kubernetes project.

## Next Stage

**Stage 1 — Mealie + PostgreSQL**

The next stage introduces the real application stack using the official Mealie v3.22.0 image and PostgreSQL 17.

