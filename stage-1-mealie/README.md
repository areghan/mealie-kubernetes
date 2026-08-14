# Stage 1 — Mealie + PostgreSQL

## Goal

Run the official Mealie application using Mealie v3.22.0 with PostgreSQL as the database.

The purpose of this stage is to understand the Mealie application and its database dependency before introducing Kubernetes.

## Architecture

```text
┌─────────────────────────┐
│     Mealie v3.22.0      │
│                         │
│ Official Mealie Image   │
└────────────┬────────────┘
             │
             │ PostgreSQL
             ▼
┌─────────────────────────┐
│      PostgreSQL 17      │
│                         │
│ Database: mealie        │
└─────────────────────────┘


## Stage 1 Results

### Deployment

Mealie v3.22.0 was successfully deployed using the official Mealie container image:

`ghcr.io/mealie-recipes/mealie:v3.22.0`

PostgreSQL 17 was deployed as the database.

### Running Services

| Service | Image | Status | Port |
|---|---|---|---|
| Mealie | ghcr.io/mealie-recipes/mealie:v3.22.0 | Healthy | 9925 → 9000 |
| PostgreSQL | postgres:17 | Healthy | 5432 internal |

### Docker Network

Docker Compose created:

`stage-1-mealie_default`

Mealie communicates with PostgreSQL using the Docker service hostname:

`postgres:5432`

PostgreSQL is not exposed directly to the host.

### Persistent Storage

Two named Docker volumes are used:

- `stage-1-mealie_mealie-data`
- `stage-1-mealie_mealie-pgdata`

### Persistence Test

A test recipe was created in Mealie.

The containers were stopped and recreated using:

```bash
docker compose down
docker compose up -d
