# Tasks: Persistence and Cache (MySQL + Redis)

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. MySQL deployment (DATA-01, DATA-04)

- [x] 1.1 Create `minikube/mysql/deployment.yaml` with one replica and `Recreate` strategy.
- [x] 1.2 Use image `mysql:8.0` with `IfNotPresent`.
- [x] 1.3 Inject `MYSQL_ROOT_PASSWORD`, `MYSQL_USER` and `MYSQL_PASSWORD` from `mysql-credentials`.
- [x] 1.4 Add `mysqladmin ping` liveness and `SELECT 1` readiness probes.
- [x] 1.5 Set requests `256Mi/250m` and limits `512Mi/500m`.

## 2. Bootstrap SQL (DATA-02)

- [x] 2.1 Create ConfigMap `mysql-init-script` with `init-db.sql`.
- [x] 2.2 Create databases `balances` and `ledger` in the script.
- [x] 2.3 Grant `ALL PRIVILEGES` on both databases to `admin`@`%`.
- [x] 2.4 Mount the ConfigMap at `/docker-entrypoint-initdb.d`.
- [ ] 2.5 Document a migration path for schema changes on an existing PVC.

## 3. Exposure and state (DATA-03, DATA-05)

- [x] 3.1 Create NodePort Service `mysql` on 3306 → NodePort 30001.
- [x] 3.2 Create PVC `mysql-pv-claim` and mount it at `/var/lib/mysql`.
- [x] 3.3 Include `minikube/mysql/` in `make apply` and `make destroy`.
- [ ] 3.4 Add a backup/restore procedure before destructive `make reload` runs.

## 4. Redis (DATA-06)

- [x] 4.1 Create Deployment `redis` using the `redis` image.
- [x] 4.2 Create NodePort Service on 6379 → NodePort 30004.
- [x] 4.3 Include `minikube/redis/` in `make apply` and `make destroy`.
- [ ] 4.4 Add a password, resource limits and probes for Redis.
- [ ] 4.5 Add a PVC if cache persistence is required.

## 5. Credentials

- [x] 5.1 Store `root`/`rootpassword` and `admin`/`adminpassword` as base64 demo values in `minikube/mysql/secrets.yaml`.
- [ ] 5.2 Replace committed demo credentials with a documented local override mechanism.
