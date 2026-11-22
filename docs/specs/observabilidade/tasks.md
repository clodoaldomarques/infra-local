# Tasks: Observability

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. OTel Collector (OBS-01, OBS-02, OBS-03, OBS-04, OBS-05)

- [x] 1.1 Create ConfigMap `otel-collector-config` with OTLP, MySQL, processors, exporters and pipelines.
- [x] 1.2 Expose gRPC 4317 and HTTP 4318 receivers.
- [x] 1.3 Configure the MySQL receiver against `mysql:3306` with the Secret-derived password.
- [x] 1.4 Add `memory_limiter` (512MiB) and `batch` (1000/1s) processors.
- [x] 1.5 Export traces to Zipkin and debug; metrics to the Prometheus exporter and debug.
- [x] 1.6 Expose `health_check` on 13133 and wire liveness/readiness probes.
- [x] 1.7 Create NodePort Service: 4317/4318 dynamic, 8889 → 30005.
- [ ] 1.8 Add a Loki exporter or a log shipper so Loki receives data.
- [ ] 1.9 Add trace sampling configuration for higher-volume tests.

## 2. Prometheus (OBS-06, OBS-07)

- [x] 2.1 Create `prometheus-config` with 15s scrape of `otel:8889` and `prometheus:9090`.
- [x] 2.2 Deploy `prom/prometheus:latest` with config and TSDB path arguments.
- [x] 2.3 Create PVC `prometheus-data` (2Gi) and mount at `/prometheus`.
- [x] 2.4 Expose the UI on NodePort 30010.
- [x] 2.5 Add `/health` liveness/readiness probes.
- [ ] 2.6 Add alerting/recording rules and a node/kube-state exporter for the Grafana cluster panels.

## 3. Zipkin (OBS-03, OBS-08)

- [x] 3.1 Deploy `openzipkin/zipkin:latest` with `STORAGE_TYPE=mem`.
- [x] 3.2 Expose port 9411 on NodePort 30009.
- [x] 3.3 Add `/health` liveness/readiness probes.
- [ ] 3.4 Replace in-memory storage with a durable backend if trace history is needed.

## 4. Grafana (OBS-09)

- [x] 4.1 Deploy `grafana/grafana:latest` with `admin`/`admin`.
- [x] 4.2 Provision `prometheus`, `tempo` and `loki` datasources from `grafana-config`.
- [x] 4.3 Provision the dashboard provider and mount ConfigMap `grafana-dashboards`.
- [x] 4.4 Install `grafana-piechart-panel`.
- [x] 4.5 Create PVC `grafana-storage` (1Gi) and expose NodePort 30011.
- [ ] 4.6 Remove or disable the Tempo datasource until Tempo is deployed.
- [ ] 4.7 Keep `dashboards-configmap.yaml` and `dashboards/6417_rev1.json` in sync via a generator or check.

## 5. Loki (OBS-10)

- [x] 5.1 Create `loki-config` with HTTP 3100, TSDB v13 filesystem storage.
- [x] 5.2 Deploy `grafana/loki:latest` with PVC `loki-data` (2Gi).
- [x] 5.3 Create a ClusterIP Service for `loki:3100`.
- [x] 5.4 Include `minikube/loki/` in `make apply` and `make destroy`.
- [ ] 5.5 Add Promtail/Fluent Bit or an OTel Loki exporter and a log pipeline.

## 6. Tempo (OBS-11)

- [x] 6.1 Keep `minikube/tempo/` with Deployment, Service, ConfigMap and PVC `tempo-data`.
- [x] 6.2 Configure HTTP 3200 and OTLP receivers on 4317/4318.
- [x] 6.3 Leave Tempo out of `make apply` and `make destroy`.
- [ ] 6.4 Decide whether to deploy Tempo and replace Zipkin, or remove the datasource and manifests.

## 7. Cross-domain (OBS-12)

- [x] 7.1 Accept k6 OTLP metrics at `otel:4317` with prefix `k6_` (see `k6-carga`).
- [x] 7.2 Document the telemetry flow in `README.md`.
