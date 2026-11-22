# Design: Observability

## Overview

A single OpenTelemetry Collector is the telemetry entry point. Traces go to Zipkin, metrics are re-exposed in Prometheus format and scraped by Prometheus, and Grafana visualizes Prometheus. Loki and Tempo exist as partially provisioned backends that are not currently fed by the collector.

## Telemetry flow

```text
 apps (OTLP) ───────────────┐
 MySQL scraper (10s) ───────┼──▶ OTel Collector ──traces──▶ Zipkin :9411 (mem) + debug
 k6 (OTLP, prefix k6_) ─────┘                    └─metrics─▶ exporter :8889 + debug
                                                                │
                                              Prometheus ──scrape──┘ (15s)
                                                                │
                                                             Grafana
```

## Components and interfaces

| Component | Source | Image | Ports | State |
|---|---|---|---|---|
| OTel Collector | `minikube/otel/` | `otel/opentelemetry-collector-contrib:0.120.0` | 4317, 4318, 8888, 8889, 13133 | none |
| Prometheus | `minikube/prometheus/` | `prom/prometheus:latest` | 9090 → NodePort 30010 | PVC `prometheus-data` 2Gi |
| Zipkin | `minikube/zipkin/` | `openzipkin/zipkin:latest` | 9411 → NodePort 30009 | in-memory |
| Grafana | `minikube/grafana/` | `grafana/grafana:latest` | 3000 → NodePort 30011 | PVC `grafana-storage` 1Gi |
| Loki | `minikube/loki/` | `grafana/loki:latest` | 3100 (ClusterIP) | PVC `loki-data` 2Gi |
| Tempo | `minikube/tempo/` | `grafana/tempo:latest` | 3200, 4317, 4318 (ClusterIP) | PVC `tempo-data` 2Gi |

### Collector pipeline (as configured)

- **Receivers**: `otlp` (gRPC 4317, HTTP 4318), `mysql` (`mysql:3306`, `root`, password from `${env:MYSQL_PASSWORD}`, 10s interval).
- **Processors**: `memory_limiter` (512MiB, 1s check), `batch` (1000 spans, 1s timeout).
- **Exporters**: `debug` (normal verbosity), `zipkin` (JSON → `http://zipkin:9411/api/v2/spans`), `prometheus` (`0.0.0.0:8889`, timestamps, 180m expiration, resource-to-telemetry conversion).
- **Extensions**: `health_check` on 13133.
- **Pipelines**: traces `[otlp] → [memory_limiter, batch] → [zipkin, debug]`; metrics `[otlp, mysql] → [memory_limiter, batch] → [prometheus, debug]`.

### Prometheus scrape configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: otel          # otel:8889/metrics
  - job_name: prometheus    # prometheus:9090/metrics
```

### Grafana provisioning

- Datasources: `prometheus` (uid `prometheus`, default, `http://prometheus:9090`), `tempo` (`http://tempo:3200`), `loki` (`http://loki:3100`).
- Dashboards provider reads `/var/lib/grafana/dashboards`, populated from ConfigMap `grafana-dashboards` (the JSON source copy is `minikube/grafana/dashboards/6417_rev1.json`; no generator exists).
- Plugin: `grafana-piechart-panel`. Admin credentials: `admin`/`admin`.

### Loki and Tempo configuration

- Loki: `auth_enabled: false`, HTTP 3100, TSDB schema v13 on filesystem, `allow_structured_metadata: true`, `volume_enabled: true`, data at `/loki`.
- Tempo: HTTP 3200, OTLP gRPC/HTTP receivers, local backend with WAL at `/var/tempo/wal` and blocks at `/var/tempo/blocks`, usage reporting disabled.

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| Zipkin for traces instead of Tempo | Simpler local setup; collector already speaks Zipkin JSON | No Tempo integration despite the datasource; in-memory loss on restart |
| Prometheus exporter in the collector | Decouples ingestion from scrape targets | Collector must stay up for metric continuity |
| Debug exporter everywhere | Makes local troubleshooting easy | Verbose logs; not suitable for production |
| Prometheus in its own PVC | Keeps metric history across pod restarts | Deleted by `make destroy` |
| Loki deployed but not wired | Prepared for a future log pipeline | Datasource is empty today |
| Tempo manifests kept but not applied | Preserves an alternative trace backend | Grafana Tempo datasource is dead until manually applied |

## Verification

```bash
kubectl get deploy,svc,pvc -l com.job.service=otel
kubectl logs deploy/otel --tail=50
curl -s http://$(minikube ip):30005/metrics | head
curl -s http://$(minikube ip):30009/health
curl -s http://$(minikube ip):30010/api/v1/targets
curl -s -o /dev/null -w '%{http_code}\n' http://$(minikube ip):30011/api/health
```

## Gaps / open issues

- No Loki exporter or log shipper (OBS-10).
- Tempo not applied by `make apply`; datasource points to a non-existent Service (OBS-11, OBS-09).
- Zipkin storage is in-memory (OBS-08).
- Grafana cluster panels query metrics no exporter provides (OBS-06).
- No alerting rules, recording rules or sampling configuration.
- Dashboard JSON and its source copy must be kept in sync manually.
