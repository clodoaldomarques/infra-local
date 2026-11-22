# Design: Persistence and Cache (MySQL + Redis)

## Overview

MySQL 8.0 is the system of record for the `balances` and `ledger` databases. Redis is a standalone, stateless cache. Both use the official images and default configuration, with credentials for MySQL sourced from a committed demo Secret.

## Components and interfaces

| Component | Source | Image | Ports | State |
|---|---|---|---|---|
| MySQL | `minikube/mysql/deployment.yaml`, `service.yaml` | `mysql:8.0` | 3306 → NodePort 30001 | PVC `mysql-pv-claim` |
| Redis | `minikube/redis/deployment.yaml`, `service.yaml` | `redis` | 6379 → NodePort 30004 | none |

### MySQL configuration

- Strategy `Recreate` (single replica, no rolling update with shared storage).
- Secrets `mysql-credentials`: `root`, `admin_user`, `admin_password` (base64 demo values).
- Init SQL at `/docker-entrypoint-initdb.d` from ConfigMap `mysql-init-script` (mode `0444`), executed only for a fresh data directory.
- Requests `256Mi/250m`, limits `512Mi/500m`.
- `terminationGracePeriodSeconds: 30`.

### Redis configuration

- No ConfigMap, Secret, PVC, resource limits or probes. Defaults from the `redis` image apply.

## Data model (as bootstrapped)

```text
balances   (database) — granted to admin@%
ledger     (database) — granted to admin@%
```

No tables are created by this repo; application migrations are expected to create them.

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| `Recreate` strategy | Avoids two pods writing the same ReadWriteOnce volume | Brief downtime on redeploy |
| Bootstrap SQL in a ConfigMap | Keeps schema initialization versioned with the infra | Changes never apply to an existing PVC |
| Grant `admin`@`%` | Lets any pod in the cluster connect with the demo user | Wide-open within the local cluster only |
| Redis without auth/persistence | Minimal local cache for development | Unsafe outside Minikube; data loss on restart |
| NodePort for both | Direct access from host tooling (mysql client, redis-cli) | Exposes demo credentials on the local network |

## Verification

```bash
kubectl get deploy,svc,pvc -l com.job.service=mysql
kubectl exec deploy/mysql -- mysql -uroot -prootpassword -e 'SHOW DATABASES;'
MYSQL_PWD=rootpassword mysql -h $(minikube ip) -P 30001 -uroot -e 'SHOW DATABASES;'
kubectl exec deploy/redis -- redis-cli ping
```

## Gaps / open issues

- Init SQL only runs on a fresh PVC; schema changes require manual migration or PVC deletion (DATA-02).
- Redis has no authentication, persistence, resource limits or probes (DATA-06).
- `make destroy` deletes `mysql-pv-claim` and therefore all local data (DATA-05).
- Credentials are committed base64 demo values; see `ciclo-de-vida-e-acesso`.
