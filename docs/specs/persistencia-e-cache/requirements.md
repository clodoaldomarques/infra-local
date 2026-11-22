# Requirements: Persistence and Cache (MySQL + Redis)

## Introduction

Reverse-engineered from `minikube/mysql/` and `minikube/redis/`. This domain covers the relational database used by the Ledger services, its bootstrap SQL, credentials and persistence, plus the standalone Redis instance.

## Glossary

- **Init script**: SQL mounted into `/docker-entrypoint-initdb.d/`, executed by the official MySQL image only on a fresh data directory.
- **PVC**: PersistentVolumeClaim; deleting it discards the database.

## Requirements

### Requirement: DATA-01 — Run a single MySQL 8.0 instance

The system SHALL run one MySQL 8.0 replica in the `default` namespace.

#### Scenario: Applying the infrastructure

- **WHEN** `make apply` is executed
- **THEN** the system SHALL create the MySQL Deployment and Service
- **AND** the container SHALL listen on port 3306

#### Scenario: Readiness

- **WHEN** the readiness probe executes
- **THEN** the system SHALL run `SELECT 1` as `root` inside the container
- **AND** the liveness probe SHALL use `mysqladmin ping`

### Requirement: DATA-02 — Bootstrap the Ledger databases

The system SHALL create databases `balances` and `ledger` and grant `ALL PRIVILEGES` on both to `admin`@`%`.

#### Scenario: Fresh data directory

- **GIVEN** an empty PVC `mysql-pv-claim`
- **WHEN** MySQL starts for the first time
- **THEN** the system SHALL execute `init-db.sql` from ConfigMap `mysql-init-script`
- **AND** both databases and the `admin`@`%` grants SHALL exist

#### Scenario: Existing data directory

- **GIVEN** a PVC that already contains a MySQL data directory
- **WHEN** the ConfigMap `mysql-init-script` is edited and MySQL restarts
- **THEN** the system SHALL NOT re-execute the init script
- **AND** the existing schemas SHALL remain unchanged

### Requirement: DATA-03 — Expose MySQL inside and outside the cluster

The system SHALL make MySQL reachable at `mysql:3306` and through NodePort `30001`.

#### Scenario: In-cluster access

- **WHEN** a workload connects to `mysql:3306`
- **THEN** the system SHALL route the connection to the MySQL pod selected by `com.job.service=mysql-db`

#### Scenario: Host access

- **WHEN** a client connects to `$(minikube ip):30001`
- **THEN** the system SHALL forward the connection to `mysql:3306`

### Requirement: DATA-04 — Read database credentials from a Secret

The system SHALL source `MYSQL_ROOT_PASSWORD`, `MYSQL_USER` and `MYSQL_PASSWORD` from Secret `mysql-credentials`.

#### Scenario: Container startup

- **WHEN** the MySQL container starts
- **THEN** the system SHALL inject the `root`, `admin_user` and `admin_password` keys
- **AND** the OTel collector SHALL use the `root` key for its MySQL scraper (see `observabilidade`)

### Requirement: DATA-05 — Persist the MySQL data directory

The system SHALL mount PVC `mysql-pv-claim` at `/var/lib/mysql`.

#### Scenario: Pod restart

- **WHEN** the MySQL Pod is recreated
- **THEN** the system SHALL reattach the same PVC and preserve the databases

#### Scenario: Infrastructure destruction

- **WHEN** `make destroy` or `make reload` runs
- **THEN** the system SHALL delete `mysql-pv-claim` and all databases with it

### Requirement: DATA-06 — Provide an unauthenticated Redis cache

The system SHALL run one Redis replica reachable at `redis:6379` (NodePort `30004`) without a password or PVC.

#### Scenario: Applying the infrastructure

- **WHEN** `make apply` is executed
- **THEN** the system SHALL create the Redis Deployment and Service

#### Scenario: Cache access

- **WHEN** a workload connects to `redis:6379`
- **THEN** the system SHALL accept commands without authentication
- **AND** cached data SHALL be lost when the pod is recreated
