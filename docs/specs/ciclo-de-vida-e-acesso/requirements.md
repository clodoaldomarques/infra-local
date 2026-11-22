# Requirements: Lifecycle and Access

## Introduction

Reverse-engineered from the `Makefile`, all `service.yaml` files, the PVC manifests and the committed Secrets. This domain covers how the environment is started, applied, destroyed and accessed, plus the safety characteristics of those operations.

## Glossary

- **Apply set**: the ten component directories applied by `make apply`.
- **NodePort**: a fixed host port mapped to a Service port on every Minikube node.
- **Demo credential**: a base64 value committed to the repository for local use only.

## Requirements

### Requirement: OPS-01 — Start and stop Minikube

The system SHALL provide Make targets to start, stop, inspect and open the dashboard of Minikube.

#### Scenario: Starting

- **WHEN** `make start` runs
- **THEN** the system SHALL execute `minikube start`
- **AND** it SHALL launch `minikube dashboard` in the background

#### Scenario: Stopping and inspecting

- **WHEN** `make stop`, `make status` or `make dashboard` runs
- **THEN** the system SHALL execute the corresponding `minikube` command

### Requirement: OPS-02 — Apply exactly the core component set

The system SHALL apply only `localstack`, `stackport`, `mysql`, `redis`, `mockserver`, `otel`, `prometheus`, `zipkin`, `loki` and `grafana`.

#### Scenario: Bootstrap

- **WHEN** `make apply` is executed
- **THEN** the system SHALL run `kubectl apply -f minikube/<component>/` for each component in that set, in that order
- **AND** it SHALL NOT apply `k6/`, `ollama/` or `tempo/`

### Requirement: OPS-03 — Destroy and reload the environment

The system SHALL delete the same component set with `--ignore-not-found`, and SHALL define `reload` as `destroy` followed by `apply`.

#### Scenario: Destruction

- **WHEN** `make destroy` runs
- **THEN** the system SHALL delete every resource in those directories, ignoring missing resources
- **AND** it SHALL delete the PVCs declared in `localstack/`, `mysql/`, `prometheus/`, `loki/` and `grafana/`

#### Scenario: Reload

- **WHEN** `make reload` runs
- **THEN** the system SHALL run `destroy` and then `apply`
- **AND** all PVC-backed data SHALL be lost

### Requirement: OPS-04 — Provide deterministic host access

The system SHALL expose the core services through fixed NodePorts.

#### Scenario: Host access

- **WHEN** a client connects to `$(minikube ip):<NodePort>`
- **THEN** the system SHALL forward the connection to the mapped Service port

#### Scenario: NodePort map

- **WHEN** the Services are created
- **THEN** the system SHALL use the map: MySQL 30001, LocalStack 30002/30003, Redis 30004, OTel metrics 30005, StackPort 30006, Ollama 30007, MockServer 30008, Zipkin 30009, Prometheus 30010, Grafana 30011

#### Scenario: Cluster-only services

- **WHEN** a client tries to reach Loki or Tempo from the host
- **THEN** no NodePort SHALL be available, because both Services are ClusterIP

### Requirement: OPS-05 — Use demo credentials

The system SHALL store local-only demo credentials in committed Secrets and ConfigMaps.

#### Scenario: Credential values

- **WHEN** a developer decodes the committed base64 values
- **THEN** they SHALL obtain: MySQL `root`/`rootpassword`, MySQL `admin`/`adminpassword`, AWS `test`/`test`, Grafana `admin`/`admin`

#### Scenario: Scope

- **WHEN** the environment is deployed
- **THEN** those credentials SHALL be valid only inside the local Minikube environment
- **AND** the system SHALL NOT provide a secret-management integration

### Requirement: OPS-06 — Support base64 generation

The system SHALL provide `make encrypt pass=<value>` that prints the base64 of the supplied value.

#### Scenario: Generating a demo Secret value

- **WHEN** `make encrypt pass=example` is executed
- **THEN** the system SHALL print the base64 encoding of `example`

### Requirement: OPS-07 — Advertise accurate Make targets

The system SHALL keep `make help`, `.PHONY` and the defined targets consistent.

#### Scenario: Current state

- **WHEN** `make help` is executed
- **THEN** it SHALL list `apply`, `destroy`, `restart`, `mysql-logs` and the `k6-*` targets
- **AND** `restart`, `mysql-logs`, `k6-config` and `k6-destroy` SHALL NOT be defined as targets

#### Scenario: Desired state

- **WHEN** a user runs a target advertised by `make help`
- **THEN** the target SHALL exist and perform the advertised action

### Requirement: OPS-08 — Deploy everything in the default namespace

The system SHALL create all resources in the `default` namespace without explicit namespace declarations.

#### Scenario: Applying manifests

- **WHEN** any `kubectl apply -f minikube/<component>/` runs
- **THEN** all resources SHALL land in the current context's `default` namespace
