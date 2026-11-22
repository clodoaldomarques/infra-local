# Requirements: k6 Load Test

## Introduction

Reverse-engineered from `minikube/k6/`. This domain covers the load-test script, its configuration, the Kubernetes resources created on demand, the SQS publishing behavior and the OTLP metric export. k6 is deliberately not part of `make apply`.

## Glossary

- **VU**: virtual user in k6.
- **Setup phase**: k6 `setup()` function, executed once before the test.
- **Job**: `k6-load-test`, a one-shot batch workload.
- **Deployment**: `k6`, which runs the same script continuously.

## Requirements

### Requirement: K6-01 — Provide an on-demand lifecycle

The system SHALL expose dedicated Make targets for k6 and SHALL NOT include k6 in `make apply`.

#### Scenario: Starting a run

- **WHEN** `make k6-run` is executed
- **THEN** the system SHALL apply `minikube/k6/configmap.yaml` and `minikube/k6/deployment.yaml`
- **AND** it SHALL delete any existing Job `k6-load-test` before applying `minikube/k6/job.yaml`

#### Scenario: Watching results

- **WHEN** `make k6-logs` is executed
- **THEN** the system SHALL follow the logs of Job `k6-load-test`

#### Scenario: Cleaning up

- **WHEN** `make k6-stop` is executed
- **THEN** the system SHALL delete all resources in `minikube/k6/`
- **AND** `make k6-reload` SHALL run `k6-stop` followed by `k6-run`

### Requirement: K6-02 — Activate the test organization before load

The system SHALL POST `{"org_id": "TN-k6-load-test"}` to `http://ledger-config:5000/v1/ledger/org/activate` during `setup()`.

#### Scenario: Activation succeeds

- **GIVEN** a Service named `ledger-config` on port 5000
- **WHEN** the endpoint returns HTTP 200
- **THEN** the setup check SHALL pass and the load phase SHALL start

#### Scenario: Already activated

- **WHEN** the endpoint returns HTTP 400 with message `tenant TN-k6-load-test was activated`
- **THEN** the setup SHALL treat the organization as activated

#### Scenario: Missing prerequisite

- **GIVEN** no `ledger-config` Service in the cluster
- **WHEN** `setup()` runs
- **THEN** the check SHALL fail and the test SHALL abort with an error

### Requirement: K6-03 — Publish messages to the LocalStack SQS queue

The system SHALL send JSON transaction messages to `http://localstack:4566/000000000000/balance-sqs-queue`.

#### Scenario: Message published

- **WHEN** a virtual user executes the default function
- **THEN** the system SHALL call `sqs.sendMessage` with a message containing `org_id`, `account_id`, `amount`, `authorization`, `correlation_id`, `program`, `transaction_type`, `processing_code` and `tax`
- **AND** the `sqs_messages_sent` counter SHALL increase

#### Scenario: Publishing fails

- **WHEN** `sendMessage` throws
- **THEN** the `sqs_errors` rate SHALL be incremented
- **AND** the `mensagem publicada no SQS` check SHALL fail

#### Scenario: Queue missing

- **GIVEN** the SQS queue does not exist (LocalStack init only creates a bucket)
- **WHEN** the load test runs
- **THEN** the error rate threshold `sqs_errors rate<0.1` SHALL be violated

### Requirement: K6-04 — Ramp virtual users and enforce thresholds

The system SHALL run stages of 10 and 25 VUs and enforce thresholds on errors, duration and checks.

#### Scenario: Stage progression

- **WHEN** the test starts
- **THEN** the system SHALL run: 1m → 10 VUs, 3m → 10 VUs, 1m → 25 VUs, 3m → 25 VUs, 1m → 0 VUs

#### Scenario: Threshold evaluation

- **WHEN** the test finishes
- **THEN** `sqs_errors` SHALL have `rate<0.1`, `sqs_send_duration` SHALL have `p(95)<500` and `checks` SHALL have `rate>0.9`

### Requirement: K6-05 — Export metrics to the OTel Collector

The system SHALL export k6 metrics as OTLP to `otel:4317` with prefix `k6_`.

#### Scenario: Running the Deployment or Job

- **WHEN** the k6 container starts
- **THEN** `K6_OUT=opentelemetry`, `K6_OTEL_GRPC_EXPORTER_ENDPOINT=otel:4317`, `K6_OTEL_GRPC_EXPORTER_INSECURE=true` and `K6_OTEL_METRIC_PREFIX=k6_` SHALL be set
- **AND** the metrics SHALL be visible in Prometheus via the collector's exporter (see `observabilidade`)

### Requirement: K6-06 — Run both a Deployment and a Job

The system SHALL define a Deployment `k6` and a Job `k6-load-test` that execute the same script.

#### Scenario: `make k6-run`

- **WHEN** the target completes
- **THEN** both the Deployment and the Job SHALL be present
- **AND** the Deployment SHALL restart the script continuously after completion

#### Scenario: Job retry

- **WHEN** the Job fails
- **THEN** the system SHALL retry at most once (`backoffLimit: 1`) with `restartPolicy: Never`

### Requirement: K6-07 — Use demo AWS credentials from a ConfigMap

The system SHALL inject LocalStack endpoint, region, credentials, queue URL and test identifiers from ConfigMap `k6-env`.

#### Scenario: Container startup

- **WHEN** the k6 container starts
- **THEN** it SHALL receive `AWS_ENDPOINT_URL=http://localstack:4566`, `AWS_REGION=us-east-1`, demo AWS keys and `LEDGER_CONFIG_URL=http://ledger-config:5000`
