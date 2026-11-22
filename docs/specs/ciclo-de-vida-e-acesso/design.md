# Design: Lifecycle and Access

## Overview

A single `Makefile` is the control plane. It uses plain `kubectl apply/delete -f <directory>` calls, relies on the current kubeconfig context (Minikube) and creates everything in `default`. There is no namespace isolation, no package manager and no template engine.

## Lifecycle

```text
make start ──▶ minikube start + dashboard &
make apply ──▶ kubectl apply -f minikube/{localstack,stackport,mysql,redis,
                                          mockserver,otel,prometheus,zipkin,
                                          loki,grafana}/
make reload ─▶ make destroy ─▶ make apply
make stop  ──▶ minikube stop
```

`k6`, `ollama` and `tempo` are intentionally outside this flow; see their own specs.

## NodePort map

| Service | Service port | NodePort |
|---|---|---|
| MySQL | 3306 | 30001 |
| LocalStack edge | 4566 | 30002 |
| LocalStack `es` (unused) | 4571 | 30003 |
| Redis | 6379 | 30004 |
| OTel Prometheus exporter | 8889 | 30005 |
| StackPort | 8080 | 30006 |
| Ollama (manual) | 11434 | 30007 |
| MockServer | 1080 | 30008 |
| Zipkin | 9411 | 30009 |
| Prometheus | 9090 | 30010 |
| Grafana | 3000 | 30011 |

Loki (3100) and Tempo (3200/4317/4318) are ClusterIP-only.

## Persistent volumes

| PVC | Component | Size | Deleted by `make destroy` |
|---|---|---|---|
| `localstack-claim` | LocalStack | 500Mi | yes |
| `mysql-pv-claim` | MySQL | — | yes |
| `prometheus-data` | Prometheus | 2Gi | yes |
| `loki-data` | Loki | 2Gi | yes |
| `grafana-storage` | Grafana | 1Gi | yes |
| `ollama-pv-claim` | Ollama | 10Gi | no (manual) |
| `tempo-data` | Tempo | 2Gi | no (not applied) |

## Credentials

| Secret / location | Keys | Demo values |
|---|---|---|
| `mysql-credentials` (`minikube/mysql/secrets.yaml`) | `root`, `admin_user`, `admin_password` | `rootpassword`, `admin`, `adminpassword` |
| `aws-credentials` (`minikube/localstack/secrets.yaml`) | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `test`, `test` |
| Grafana env (`minikube/grafana/deployment.yaml`) | admin user/password | `admin`/`admin` |

`make encrypt pass=<value>` is just `echo -n <value> | base64`.

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| One directory per component | Simple, isolated manifests | Duplication of common labels/metadata |
| `kubectl apply -f <dir>` | No templating or tooling dependency | Ordering is implicit in the Makefile recipe |
| Fixed NodePorts | Stable URLs for host tooling | Port collisions on the host are possible |
| Delete PVCs on destroy | Guarantees a clean rebuild | Destructive; no confirmation prompt |
| Demo credentials in Git | Zero-setup local development | Must never be reused outside Minikube |
| `default` namespace only | Minimal context switching | No multi-tenant isolation |

## Verification

```bash
make status
make apply
kubectl get all,pvc -A
minikube ip
make help
make destroy
```

## Gaps / open issues

- `make help` and `.PHONY` drift from the actual recipes (OPS-07).
- No confirmation before destructive `destroy`/`reload` (OPS-03).
- No explicit namespace or kubeconfig context check before applying.
- No `k6-config` / `k6-destroy` implementation despite `.PHONY` entries.
- `make encrypt` uses `echo -n` without shell escaping for values with special characters.
