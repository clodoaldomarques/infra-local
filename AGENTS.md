# AGENTS.md

## Repo shape
- Local-only Minikube/Kubernetes infra: no app code, tests, lint, CI, lockfiles or build/typecheck commands. The Go-ish `.gitignore` is leftover; there is no Go module.
- All manifests are plain YAML under `minikube/<component>/`, in the `default` namespace. No Helm, Kustomize or Compose setup (no `docker-compose.yaml`).

## Lifecycle: trust the Makefile, not the README
- `make apply` applies exactly: localstack, stackport, mysql, redis, mockserver, otel, prometheus, zipkin, loki, grafana. It does not apply `k6/`, `ollama/` or `tempo/`.
- `make destroy` / `make reload` also delete the PVCs declared in localstack, mysql, prometheus, loki and grafana — destructive for that data.
- `make start` starts Minikube and launches the dashboard in the background; `make dashboard`, `make stop`, `make status` exist; `make reload` = `destroy` + `apply`.
- README is stale: it says Tempo is applied and documents non-existent `make up/down` Compose targets; `make help` is incomplete. `.PHONY` lists `restart`, `mysql-logs`, `k6-config`, `k6-destroy`, but those targets are undefined.

## Focused workflows
- k6: `make k6-run` applies `k6/configmap.yaml` + `k6/deployment.yaml`, deletes/recreates Job `k6-load-test`; `make k6-logs` tails it; `make k6-stop` removes all k6 resources; `make k6-reload` = stop + run. Note the Deployment also runs the same script continuously, so a run starts both a Deployment and the Job.
- k6 prerequisites are not provisioned here: `setup()` POSTs `http://ledger-config:5000/v1/ledger/org/activate` (no such Service in this repo) and publishes to SQS `http://localstack:4566/000000000000/balance-sqs-queue`; LocalStack init only creates the S3 bucket `_extension`. Create the queue and expose `ledger-config` first.
- Ollama is manual: `kubectl apply -f minikube/ollama/`, then Job `ollama-setup` pulls `qwen2.5-coder:1.5b` and creates custom model `griphook` from `Modelfile`; the Deployment requests 4Gi and limits 5Gi.
- MySQL init SQL creates `balances` and `ledger` and grants `admin`@`%`; it only runs on a fresh PVC, so ConfigMap edits do not change an existing database.

## Telemetry wiring
- OTel Collector: OTLP gRPC `:4317` / HTTP `:4318`, MySQL scraper at `mysql:3306` using secret `mysql-credentials` key `root`; traces -> Zipkin `zipkin:9411/api/v2/spans` + debug, metrics -> Prometheus exporter `:8889` + debug. No Loki or Tempo exporter is configured.
- Prometheus scrapes only `otel:8889` and itself. The bundled Kubernetes dashboard queries `kube_*` / `node_*` metrics that nothing here exports, so those panels stay empty without extra exporters.
- Loki is deployed and configured in Grafana, but no log pipeline feeds it. Tempo manifests exist and Grafana has a Tempo datasource, but `make apply` never deploys Tempo.

## Access and static config
- NodePorts: MySQL 30001, LocalStack 30002 (4566) / 30003 (4571), Redis 30004, OTel metrics 30005, StackPort 30006, Ollama 30007, MockServer 30008, Zipkin 30009, Prometheus 30010, Grafana 30011 (admin/admin).
- Grafana provisions datasources from `grafana/configmap.yaml` (`Prometheus` uid `prometheus` is default, plus `tempo` and `loki`) and loads dashboards from ConfigMap `grafana-dashboards`. `dashboards-configmap.yaml` embeds ~2.6k lines of JSON; `dashboards/6417_rev1.json` is the source copy and there is no generator — keep them in sync manually.
- Committed credentials in `mysql/secrets.yaml` and `localstack/secrets.yaml` are base64 demo values, not secret management; `make encrypt` is just `echo -n ... | base64`. Local-only; do not reuse elsewhere.
