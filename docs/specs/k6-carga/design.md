# Design: k6 Load Test

## Overview

The k6 load test is an optional, on-demand workload. Its script lives in a ConfigMap and is mounted into both a Deployment (continuous) and a one-shot Job. The script activates a test organization through an external service, publishes transaction messages to LocalStack SQS, and exports metrics to the OTel Collector.

## Components and interfaces

| Resource | Source | Image | Notes |
|---|---|---|---|
| ConfigMap `k6-env` | `minikube/k6/configmap.yaml` | — | endpoint, queue URL, credentials, test IDs |
| ConfigMap `k6-script` | `minikube/k6/configmap.yaml` | — | embedded `script.js` |
| Deployment `k6` | `minikube/k6/deployment.yaml` | `grafana/k6:latest` | `k6 run /scripts/script.js`, restarts continuously |
| Job `k6-load-test` | `minikube/k6/job.yaml` | `grafana/k6:latest` | `restartPolicy: Never`, `backoffLimit: 1` |

## Script flow

```text
setup()  ──POST /v1/ledger/org/activate──▶ ledger-config:5000
default() ──SQS SendMessage──────────────▶ localstack:4566/.../balance-sqs-queue
metrics  ──OTLP gRPC (prefix k6_)────────▶ otel:4317 ──▶ Prometheus
```

### Message shape (built by `buildMessage()`)

- Identifiers: `org_id`, `account_id`, `id`, `correlation_id` (derived from VU, iteration and timestamp).
- Financial data: `accounting_date`, `amount[]` (BRL), `authorization`, `tax[]` (IOF), `rates[]`.
- Classification: `program`, `transaction_type`, `processing_code`, `processing_description`.

### Configuration and thresholds

- Stages: 1m@10, 3m@10, 1m@25, 3m@25, 1m@0 VUs.
- Thresholds: `sqs_errors rate<0.1`, `sqs_send_duration p(95)<500`, `checks rate>0.9`.
- Custom metrics: `Rate sqs_errors`, `Trend sqs_send_duration`, `Counter sqs_messages_sent`.
- Imports `https://jslib.k6.io/aws/0.14.0/sqs.js` at runtime (requires network access from the pod).

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| Script in a ConfigMap | Easy to edit and re-apply without rebuilding an image | Large inline JS; no local lint/test cycle |
| Both Deployment and Job | Job gives a bounded run, Deployment keeps generating traffic | Two producers run simultaneously; can surprise operators |
| OTLP output instead of stdout | Metrics land in the existing Prometheus/Grafana stack | Depends on the collector being healthy |
| Demo credentials in a ConfigMap | Simple for local use | Not a secret-management solution |
| `make k6-run` deletes/recreates the Job | Guarantees a fresh run | Destroys previous Job history |

## Verification

```bash
make k6-run
kubectl get deploy,job,configmap -l app=k6 -o wide
make k6-logs
kubectl exec deploy/localstack -- awslocal sqs get-queue-attributes \
  --queue-url http://localstack:4566/000000000000/balance-sqs-queue \
  --attribute-names ApproximateNumberOfMessages
make k6-stop
```

## Gaps / open issues

- `ledger-config:5000` Service does not exist in this repo (K6-02).
- `balance-sqs-queue` is not created by LocalStack init (K6-03); see `aws-localstack`.
- No Service or Ingress for k6; only logs and OTLP metrics.
- Job has no TTL; completed/failed Jobs accumulate until `make k6-stop`.
- The image is unpinned (`grafana/k6:latest`) and the script fetches a remote jslib module at runtime.
- `.PHONY` declares `k6-config` and `k6-destroy`, which are not defined (see `ciclo-de-vida-e-acesso`).
