# Design: AWS Local Stack (LocalStack + StackPort)

## Overview

LocalStack emulates a fixed subset of AWS APIs behind one edge endpoint. StackPort is an auxiliary HTTP service pre-configured to consume that endpoint. Both are plain Kubernetes resources in the `default` namespace, applied and removed by the `Makefile`.

## Components and interfaces

| Component | Source | Image | Ports | Depends on |
|---|---|---|---|---|
| LocalStack | `minikube/localstack/deployment.yaml`, `service.yaml` | `localstack/localstack:3.7.0` | 4566 (edge), 4571 (mapped, unused) | Secret `aws-credentials`, PVC `localstack-claim`, ConfigMap `localstack-init-scripts` |
| StackPort | `minikube/stackport/deployment.yaml`, `service.yaml` | `davireis/stackport:latest` | 8080 | LocalStack edge, Secret `aws-credentials` |

### Configuration

- `SERVICES=sqs,sns,dynamodb,s3`, `AWS_DEFAULT_REGION=us-east-1`, `DATA_DIR=/var/lib/localstack`, `LS_LOG=warn`, `DEBUG=0`.
- `EXTENSION_AUTO_INSTALL=localstack-extension-platform-observability` — installs an observability extension; it is not wired to the collector in this repo.
- The init ConfigMap is mounted at `/etc/localstack/init/ready.d/` with mode `0755`.
- Resource requests/limits for LocalStack: `512Mi/500m` → `1024Mi/1000m`.

## Data and state

- PVC `localstack-claim`, 500Mi, ReadWriteOnce, mounted at `/var/lib/localstack`.
- The only bootstrapped resource is bucket `_extension` (`init-bucket.sh`).
- Secrets are base64 demo values (`test` / `test`); there is no external secret manager.

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| Single edge port 4566 | Mirrors the real AWS endpoint pattern; one Service port for all services | Requires `awslocal`/`--endpoint-url` on every client |
| Fixed `SERVICES` list | Keeps startup fast and predictable | Adding a new AWS service requires a manifest edit and restart |
| Non-root container (UID 1000) | Reduces risk when mounting a host-backed volume | Some LocalStack extensions may need extra permissions |
| Init script only creates a bucket | Avoids hard-coded queues/topics that differ per test | Consumers such as k6 must provision their own queue (see `k6-carga`) |
| Port 4571 mapped but unused | Present in the Service definition | Misleading; Elasticsearch is not enabled |

## Verification

```bash
kubectl get deployment,service,pvc -l com.job.service=localstack
kubectl exec deploy/localstack -- awslocal s3 ls
curl -s http://$(minikube ip):30002/_localstack/health
curl -s -o /dev/null -w '%{http_code}\n' http://$(minikube ip):30006
```

## Gaps / open issues

- No SQS queue, SNS topic or DynamoDB table is created (AWS-03).
- Port 4571 / NodePort 30003 is exposed without a backing service.
- Credentials are committed demo values; see `ciclo-de-vida-e-acesso`.
- `make destroy` removes the PVC and therefore all LocalStack state.
