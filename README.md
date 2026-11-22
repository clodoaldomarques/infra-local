# Infra Local

> Reusable local cloud-native infrastructure for development and testing with Minikube, Kubernetes, AWS-compatible services and observability tools.

## Overview

Infra Local is a reusable local development environment that centralizes the shared infrastructure used by backend services and distributed applications.

It runs on Minikube and brings together databases, AWS-compatible services, caching, API mocking, observability, load testing and a local model runtime. The goal is to avoid duplicating infrastructure configuration across individual application repositories and to provide a consistent environment for developing and testing distributed systems.

Everything is plain YAML under `minikube/<component>/`, in the `default` namespace. There is no Helm, Kustomize or Docker Compose setup.

## What is available

| Component | Purpose | Applied by `make apply` |
|---|---|---|
| Minikube | Local Kubernetes cluster | cluster itself |
| LocalStack | AWS-compatible services (SQS, SNS, DynamoDB, S3) | yes |
| MySQL 8.0 | Relational database (`balances`, `ledger`) | yes |
| Redis | In-memory store / cache | yes |
| MockServer | HTTP service mocking | yes |
| StackPort | Local AWS stack access | yes |
| OpenTelemetry Collector | OTLP receivers, MySQL scraper, telemetry routing | yes |
| Prometheus | Metrics collection | yes |
| Zipkin | Trace storage/UI (current traces backend) | yes |
| Loki | Log storage | yes |
| Grafana | Dashboards and datasources | yes |
| Ollama | Local LLM runtime | no — manual |
| k6 | Load testing | no — on demand |
| Tempo | Distributed tracing backend | no — manifests only |

## Architecture

```text
                         ┌───────────────────────────────┐
                         │            Minikube           │
                         │          (default ns)         │
                         └───────────────┬───────────────┘
          ┌──────────────────────────────┼──────────────────────────────┐
          ▼                              ▼                              ▼
 ┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
 │ Stateful (PVCs)  │          │ AWS emulation    │          │ Tooling          │
 │ MySQL, LocalStack│          │ LocalStack       │          │ Redis, MockServer│
 │ Prometheus, Loki │          │ StackPort        │          │ Ollama*, k6*     │
 │ Grafana          │          └──────────────────┘          └────────┬─────────┘
 └──────────────────┘                                                 │ OTLP
                                                                      ▼
                                                        ┌──────────────────────────┐
                                                        │       Observability      │
                                                        │  OTel ──▶ Zipkin         │
                                                        │       └─▶ Prometheus     │
                                                        │  Grafana                │
                                                        │  Loki (no pipeline)*     │
                                                        │  Tempo (not deployed)*   │
                                                        └──────────────────────────┘

 * not part of `make apply`
```

### Telemetry flow

```text
 applications ──OTLP gRPC :4317 / HTTP :4318──▶ OTel Collector
 MySQL (mysql:3306, root) ──MySQL scraper──────▶      │
                                                     ├─ traces ──▶ Zipkin :9411 (+ debug)
                                                     └─ metrics ─▶ Prometheus exporter :8889 (+ debug)
                                                                          │
                                              Prometheus ──scrape──────────┘
                                              (also scrapes itself)
                                                     │
                                                  Grafana
```

The collector uses `memory_limiter` + `batch` processors, exports traces to `http://zipkin:9411/api/v2/spans` and exposes Prometheus-format metrics on `0.0.0.0:8889`. Prometheus scrapes `otel:8889` and `prometheus:9090` every 15s. There is **no** Loki or Tempo exporter configured in the collector.

## Kubernetes resources

All manifests live under `minikube/`:

```text
minikube/
├── grafana/        # Deployment, Service, PVC, datasource/dashboard ConfigMaps
├── k6/             # ConfigMaps, Deployment and Job (on demand)
├── localstack/     # Deployment, Service, PVC, credentials, init script
├── loki/           # Deployment, Service, PVC, ConfigMap
├── mockserver/     # Deployment, Service, expectations ConfigMap
├── mysql/          # Deployment, Service, PVC, credentials, init SQL
├── ollama/         # Deployment, Service, PVC, setup Job, Modelfile ConfigMap
├── otel/           # Deployment, Service, collector ConfigMap
├── prometheus/     # Deployment, Service, PVC, scrape ConfigMap
├── redis/          # Deployment, Service
├── stackport/      # Deployment, Service
├── tempo/          # Deployment, Service, PVC, ConfigMap (not applied by the Makefile)
└── zipkin/         # Deployment, Service
```

## Components

### LocalStack

LocalStack 3.7 emulates `sqs,sns,dynamodb,s3` in `us-east-1` and is reachable at `localstack:4566` (NodePort `30002`). The Service also maps port `4571` to NodePort `30003`, but Elasticsearch is not in `SERVICES`.

The ready-script in `minikube/localstack/configmap.yaml` only creates the S3 bucket `_extension`. **No SQS queue is created automatically** — the k6 test, for example, expects `balance-sqs-queue` in account `000000000000`:

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test \
  aws --endpoint-url http://$(minikube ip):30002 \
      sqs create-queue --queue-name balance-sqs-queue --region us-east-1
```

### MySQL

MySQL 8.0 stores its data in PVC `mysql-pv-claim`. The init script in `minikube/mysql/configmap.yaml` creates the databases `balances` and `ledger` and grants privileges to `admin`@`%`. It only runs when the PVC is fresh, so editing the ConfigMap does not change an existing database.

### Redis, MockServer and StackPort

- **Redis** listens on `redis:6379` (NodePort `30004`).
- **MockServer** listens on `mockserver:1080` (NodePort `30008`) and loads the expectations from `minikube/mockserver/configmap.yaml` (`/api/health`, `/api/users`).
- **StackPort** listens on `stackport:8080` (NodePort `30006`) and is configured to use `http://localstack:4566`.

### Grafana

Grafana is available on NodePort `30011` with `admin` / `admin`. Datasources are provisioned from `minikube/grafana/configmap.yaml`:

- `prometheus` — `http://prometheus:9090` (default)
- `tempo` — `http://tempo:3200`
- `loki` — `http://loki:3100`

Dashboards are loaded from ConfigMap `grafana-dashboards`, which embeds the JSON from `minikube/grafana/dashboards/6417_rev1.json`. There is no generator, so keep both in sync manually. Some bundled panels query `kube_*` / `node_*` metrics that nothing in this repo exports, so they stay empty without additional exporters.

### Ollama (manual)

Ollama is **not** part of `make apply`. Deploy it explicitly:

```bash
kubectl apply -f minikube/ollama/
kubectl logs -f job/ollama-setup
```

The `ollama-setup` Job pulls `qwen2.5-coder:1.5b`, copies the `Modelfile` from the ConfigMap and creates the custom model `griphook` (a JSON-only business-rules validator). Models are persisted in PVC `ollama-pv-claim` (10Gi), shared with the Deployment. The service exposes `ollama:11434` on NodePort `30007`; the Deployment requests 4Gi and is limited to 5Gi of memory.

### k6 load test (on demand)

```bash
make k6-run       # apply ConfigMaps + Deployment, recreate Job k6-load-test
make k6-logs      # tail the Job logs
make k6-stop      # remove all k6 resources
make k6-reload    # k6-stop + k6-run
```

The script publishes transaction messages to SQS and sends metrics to `otel:4317` with the `k6_` prefix, so they end up in Prometheus through the collector. `make k6-run` starts **both** a Deployment (which runs the same script continuously) and the `k6-load-test` Job.

Prerequisites are **not** provisioned by this repo:

- a Service named `ledger-config` on port `5000` with `POST /v1/ledger/org/activate` — `setup()` calls it before the test starts;
- the SQS queue `http://localstack:4566/000000000000/balance-sqs-queue` (see [LocalStack](#localstack)).

### Loki and Tempo — current status

Loki is deployed and configured in Grafana, but no log pipeline feeds it: the OTel collector has no Loki exporter. Tempo manifests exist and Grafana has a Tempo datasource, but `make apply` never creates the Tempo Deployment/Service/PVC. Traces are currently sent to Zipkin instead.

## Accessing the environment

Use `minikube ip` to build the NodePort URLs.

| Service | In-cluster address | NodePort |
|---|---|---|
| MySQL | `mysql:3306` | 30001 |
| LocalStack (edge / unused `es` port) | `localstack:4566` / `:4571` | 30002 / 30003 |
| Redis | `redis:6379` | 30004 |
| OTel Collector (OTLP gRPC / HTTP) | `otel:4317` / `otel:4318` | dynamic |
| OTel Prometheus exporter | `otel:8889` | 30005 |
| StackPort | `stackport:8080` | 30006 |
| Ollama (manual) | `ollama:11434` | 30007 |
| MockServer | `mockserver:1080` | 30008 |
| Zipkin | `zipkin:9411` | 30009 |
| Prometheus | `prometheus:9090` | 30010 |
| Grafana | `grafana:3000` | 30011 |
| Loki | `loki:3100` | — (ClusterIP) |
| Tempo (not deployed) | `tempo:3200` (if applied manually) | — (no Service from `make apply`) |

Examples:

```bash
IP=$(minikube ip)
echo "Grafana:    http://$IP:30011"   # admin / admin
echo "Zipkin:     http://$IP:30009"
echo "Prometheus: http://$IP:30010"
```

## Makefile commands

| Target | Description |
|---|---|
| `make help` | Lists targets (the list is partial and includes two undefined ones: `restart`, `mysql-logs`) |
| `make start` | `minikube start` + launch the dashboard in the background |
| `make stop` | `minikube stop` |
| `make status` | `minikube status` |
| `make dashboard` | Launch the Kubernetes dashboard in the background |
| `make apply` | Apply localstack, stackport, mysql, redis, mockserver, otel, prometheus, zipkin, loki, grafana |
| `make destroy` | Delete those resources with `--ignore-not-found` |
| `make reload` | `destroy` + `apply` |
| `make k6-run` / `make k6-logs` / `make k6-stop` / `make k6-reload` | Manage the k6 resources |
| `make encrypt pass=<value>` | Print a base64 value (used for the demo Secrets) |

`make destroy` — and therefore `make reload` — also **deletes the PVCs** for LocalStack, MySQL, Prometheus, Loki and Grafana. Treat both as destructive for that data; `make apply` creates the PVCs again on the next run.

## Getting started

### Requirements

- Docker
- Minikube
- kubectl
- Make

### Clone and deploy

```bash
git clone https://github.com/clodoaldomarques/infra-local.git
cd infra-local

make start
make apply
kubectl get pods -A
kubectl get services -A
```

Then open Grafana (`http://$(minikube ip):30011`, `admin`/`admin`) or Zipkin (`http://$(minikube ip):30009`).

Deploy Ollama and k6 separately as described above; Tempo is not deployed by the Makefile.

## Credentials

All credentials are committed base64 **demo values for local use only** (`root`/`rootpassword`, `admin`/`adminpassword`, AWS `test`/`test`, Grafana `admin`/`admin`). Do not reuse them outside this local environment.

## Known gaps

- Tempo is not deployed by `make apply`, even though Grafana provisions a Tempo datasource.
- Loki has no log pipeline; no collector exporter or Promtail/Fluent Bit ships logs to it.
- The bundled Grafana dashboard expects `kube_*` / `node_*` metrics that are not exported here.
- k6 needs an external `ledger-config` Service and a pre-created SQS queue.
- `minikube/grafana/dashboards-configmap.yaml` and `dashboards/6417_rev1.json` must be kept in sync by hand.
- `make help` also advertises `restart` and `mysql-logs`, which are not defined in the Makefile.

## Design goals

- **Centralization** — shared infrastructure should not be duplicated across application repositories.
- **Reproducibility** — developers should be able to recreate the same local environment.
- **Automation** — the lifecycle is driven by simple Make targets.
- **Isolation** — each component owns its Kubernetes resources.
- **Cloud-native development** — applications are developed against patterns similar to production.
- **Observability by default** — traces and metrics are available during local development.
- **Local-first experimentation** — cloud services, load testing and AI models run without external environments.

## Use cases

Developing and testing Go backend services, microservices, event-driven applications, AWS integrations, asynchronous workers, distributed systems, REST APIs, observability instrumentation, Kubernetes workloads and local AI integrations.

## Relationship with the Ledger projects

This repository acts as shared infrastructure for local development and can support the other backend projects in the Ledger ecosystem (Ledger Events, Ledger Worker, Ledger Config). Application repositories stay focused on business logic while infrastructure is maintained independently. Note that the k6 test specifically depends on a `ledger-config` Service being available in the cluster.

## Project status

This project is part of a backend engineering portfolio and serves as a reusable local infrastructure environment for experimenting with cloud-native applications, distributed systems, observability and Kubernetes. It is intentionally designed for local development and experimentation rather than production deployment.

## Author

**Clodoaldo Marques**

Backend Software Engineer focused on Go, Microservices, Distributed Systems and Cloud-Native architectures.

- GitHub: https://github.com/clodoaldomarques
- LinkedIn: https://www.linkedin.com/in/clodoaldomarques/
