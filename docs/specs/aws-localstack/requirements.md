# Requirements: AWS Local Stack (LocalStack + StackPort)

## Introduction

Reverse-engineered from `minikube/localstack/` and `minikube/stackport/`. This domain covers the local emulation of AWS-compatible APIs, the auxiliary access service, the initialization script, credentials and the external access paths.

## Glossary

- **Edge endpoint**: the single LocalStack port (4566) that multiplexes all emulated AWS services.
- **Ready script**: a script mounted into `/etc/localstack/init/ready.d/` and executed once LocalStack reports ready.
- **StackPort**: a separate image (`davireis/stackport`) configured to talk to the LocalStack edge endpoint.

## Requirements

### Requirement: AWS-01 — Provision LocalStack with a fixed service set

The system SHALL run one LocalStack `3.7.0` replica with `SERVICES=sqs,sns,dynamodb,s3` in region `us-east-1`.

#### Scenario: Applying the infrastructure

- **WHEN** `make apply` is executed
- **THEN** the system SHALL apply `minikube/localstack/` in the `default` namespace
- **AND** the LocalStack container SHALL listen on the edge port 4566

#### Scenario: Health probing

- **WHEN** the liveness or readiness probe runs
- **THEN** the system SHALL perform an HTTP GET on `/_localstack/health` at port 4566

### Requirement: AWS-02 — Expose the edge endpoint inside and outside the cluster

The system SHALL make LocalStack reachable at `localstack:4566` from other pods and through NodePort `30002` from the host.

#### Scenario: In-cluster access

- **GIVEN** another workload in the `default` namespace
- **WHEN** it sends a request to `http://localstack:4566`
- **THEN** the system SHALL route the request to the LocalStack edge port

#### Scenario: Host access

- **WHEN** a client connects to `http://$(minikube ip):30002`
- **THEN** the system SHALL forward the connection to `localstack:4566`

#### Scenario: Additional mapped port

- **WHEN** the Service is created
- **THEN** the system SHALL also map port 4571 to NodePort 30003 (named `es`)
- **AND** the system SHALL not enable Elasticsearch, because `es` is absent from `SERVICES`

### Requirement: AWS-03 — Initialize only the S3 bucket

The system SHALL create the S3 bucket `_extension` via the ready script and SHALL NOT create queues, topics or tables.

#### Scenario: First startup

- **WHEN** LocalStack finishes its ready phase
- **THEN** the ready script SHALL execute `awslocal s3 mb s3://_extension`

#### Scenario: No implicit SQS provisioning

- **WHEN** `make apply` completes
- **THEN** no SQS queue SHALL exist
- **AND** a workload requiring `balance-sqs-queue` SHALL fail until the queue is created explicitly

### Requirement: AWS-04 — Use demo AWS credentials from a Secret

The system SHALL read `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the Secret `aws-credentials`.

#### Scenario: Container startup

- **WHEN** the LocalStack or StackPort container starts
- **THEN** the system SHALL inject both keys from `aws-credentials`
- **AND** the default region SHALL be `us-east-1`

### Requirement: AWS-05 — Persist LocalStack state

The system SHALL persist `/var/lib/localstack` in the PVC `localstack-claim` (500Mi, ReadWriteOnce).

#### Scenario: Pod restart

- **WHEN** the LocalStack Pod is deleted and recreated
- **THEN** the system SHALL remount the same PVC at `/var/lib/localstack`

#### Scenario: Infrastructure destruction

- **WHEN** `make destroy` or `make reload` runs
- **THEN** the system SHALL delete `localstack-claim` together with the other resources

### Requirement: AWS-06 — Provide StackPort as an auxiliary access service

The system SHALL deploy one StackPort replica listening on `stackport:8080` (NodePort `30006`) pointed at `http://localstack:4566`.

#### Scenario: StackPort startup

- **WHEN** `make apply` is executed
- **THEN** the system SHALL create the StackPort Deployment and Service
- **AND** the container SHALL receive `AWS_ENDPOINT_URL=http://localstack:4566`, the AWS credentials and `STACKPORT_PORT=8080`

### Requirement: AWS-07 — Run LocalStack as a non-root user

The system SHALL run the LocalStack container as UID 1000 with privilege escalation disabled.

#### Scenario: Security context evaluation

- **WHEN** the Pod is admitted
- **THEN** `runAsNonRoot` SHALL be `true`, `runAsUser` SHALL be `1000` and `allowPrivilegeEscalation` SHALL be `false`
