# Requirements: Observability (OTel + Prometheus + Zipkin + Grafana + Loki/Tempo)

## Introduction

Reverse-engineered from `minikube/otel/`, `minikube/prometheus/`, `minikube/zipkin/`, `minikube/grafana/`, `minikube/loki/` and `minikube/tempo/`. This domain covers telemetry ingestion, trace storage, metric storage, dashboards, and the two components that are deployed/configured but not fed.

## Glossary

- **Collector**: `otel/opentelemetry-collector-contrib:0.120.0` instance that receives OTLP and scrapes MySQL.
- **Prometheus exporter**: the collector's exporter that serves metrics at `0.0.0.0:8889` for Prometheus to scrape.
- **Debug exporter**: collector exporter that writes telemetry to the container logs.

## Requirements

### Requirement: OBS-01 — Receive OTLP traces and metrics

The system SHALL expose OTLP over gRPC on `otel:4317` and over HTTP on `otel:4318`.

#### Scenario: Application instrumentation

- **WHEN** an application exports OTLP spans or metrics to `otel:4317` or `otel:4318`
- **THEN** the collector SHALL accept the data on `0.0.0.0:4317` / `0.0.0.0:4318`
- **AND** the data SHALL pass through `memory_limiter` and `batch` processors

#### Scenario: Host access to the exporter

- **WHEN** a client connects to `$(minikube ip):30005`
- **THEN** the system SHALL forward the connection to the collector's metrics port 8889
- **AND** OTLP gRPC/HTTP SHALL use dynamically assigned NodePorts

### Requirement: OBS-02 — Scrape MySQL metrics

The system SHALL scrape `mysql:3306` every 10 seconds as `root` using the `root` key of Secret `mysql-credentials`.

#### Scenario: Collector startup

- **WHEN** the collector starts
- **THEN** it SHALL connect to `mysql:3306` with the injected `MYSQL_PASSWORD`
- **AND** the scraped metrics SHALL enter the metrics pipeline

#### Scenario: Missing MySQL

- **WHEN** MySQL is unavailable
- **THEN** the collector SHALL log a scrape error
- **AND** the collector process SHALL remain running

### Requirement: OBS-03 — Send traces to Zipkin

The system SHALL export all received traces to Zipkin at `http://zipkin:9411/api/v2/spans` in JSON format, and to the debug exporter.

#### Scenario: Trace received

- **WHEN** a span arrives through the OTLP receiver
- **THEN** the system SHALL batch it and SHALL export it to Zipkin and to the debug exporter
- **AND** no trace SHALL be exported to Tempo or Loki

### Requirement: OBS-04 — Expose metrics for Prometheus

The system SHALL serve collector metrics at `0.0.0.0:8889` with timestamps, 180m expiration and resource-to-telemetry conversion enabled.

#### Scenario: Metrics pipeline

- **WHEN** OTLP or MySQL metrics arrive
- **THEN** the system SHALL expose them at `otel:8889/metrics`
- **AND** the debug exporter SHALL also log them

### Requirement: OBS-05 — Provide a collector health endpoint

The system SHALL expose the `health_check` extension on `0.0.0.0:13133` and use it for liveness and readiness probes.

#### Scenario: Probe execution

- **WHEN** Kubernetes probes the collector on port 13133
- **THEN** the extension SHALL return an HTTP response on path `/`

### Requirement: OBS-06 — Scrape only the collector and Prometheus

The system SHALL configure Prometheus to scrape `otel:8889` and `prometheus:9090` every 15 seconds.

#### Scenario: Scrape cycle

- **WHEN** Prometheus runs a scrape cycle
- **THEN** it SHALL collect from both configured jobs
- **AND** it SHALL NOT discover or scrape any other Kubernetes target

#### Scenario: Missing cluster metrics

- **WHEN** a Grafana panel queries `kube_*` or `node_*` metrics
- **THEN** the panel SHALL remain empty, because no kube-state-metrics or node-exporter is deployed

### Requirement: OBS-07 — Persist and expose Prometheus

The system SHALL run `prom/prometheus:latest` with its TSDB in PVC `prometheus-data` (2Gi) and expose the UI on NodePort `30010`.

#### Scenario: Prometheus restart

- **WHEN** the Prometheus Pod is recreated
- **THEN** the system SHALL remount `prometheus-data` and preserve historical metrics

#### Scenario: Destruction

- **WHEN** `make destroy` or `make reload` runs
- **THEN** the system SHALL delete `prometheus-data`

### Requirement: OBS-08 — Store traces in Zipkin with in-memory storage

The system SHALL run `openzipkin/zipkin:latest` with `STORAGE_TYPE=mem` and expose its UI on NodePort `30009`.

#### Scenario: Trace query

- **WHEN** a user opens `http://$(minikube ip):30009`
- **THEN** Zipkin SHALL display spans received from the collector

#### Scenario: Zipkin restart

- **WHEN** the Zipkin Pod is recreated
- **THEN** all previously stored traces SHALL be lost

### Requirement: OBS-09 — Provision Grafana datasources and dashboards

The system SHALL run Grafana with admin/admin, provision `prometheus` (default), `tempo` and `loki` datasources, and load dashboards from ConfigMap `grafana-dashboards`.

#### Scenario: Grafana startup

- **WHEN** Grafana starts
- **THEN** `datasources.yaml` and `dashboards.yaml` SHALL be mounted from ConfigMap `grafana-config`
- **AND** the dashboards embedded in `grafana-dashboards` SHALL be available in the `default` folder

#### Scenario: Tempo datasource without backend

- **WHEN** Grafana tries to query the `tempo` datasource
- **THEN** the query SHALL fail, because `make apply` never creates the Tempo Service

#### Scenario: Loki datasource without data

- **WHEN** a user queries the `loki` datasource
- **THEN** no logs SHALL appear, because no log pipeline ships data to Loki

### Requirement: OBS-10 — Deploy Loki without a log pipeline

The system SHALL deploy Loki 3100 with filesystem TSDB storage in PVC `loki-data` (2Gi) and a ClusterIP Service, but SHALL NOT configure any shipper or collector exporter toward it.

#### Scenario: Applying the infrastructure

- **WHEN** `make apply` is executed
- **THEN** the Loki Deployment, Service and PVC SHALL be created
- **AND** no Fluent Bit, Promtail or Loki exporter SHALL be created

### Requirement: OBS-11 — Keep Tempo as manifests only

The system SHALL keep `minikube/tempo/` out of `make apply`.

#### Scenario: Normal bootstrap

- **WHEN** `make apply` completes
- **THEN** no Deployment, Service or PVC named `tempo` / `tempo-data` SHALL exist

#### Scenario: Optional manual deployment

- **WHEN** an operator runs `kubectl apply -f minikube/tempo/`
- **THEN** Tempo SHALL listen on 3200 with OTLP receivers on 4317/4318 and local storage in PVC `tempo-data`
- **AND** the collector SHALL still not export traces to it

### Requirement: OBS-12 — Ingest k6 metrics through the collector

The system SHALL accept OTLP metrics from k6 at `otel:4317` with prefix `k6_` and expose them through the Prometheus exporter.

#### Scenario: Load test running

- **WHEN** k6 exports metrics with `K6_OUT=opentelemetry`
- **THEN** the collector SHALL receive them and Prometheus SHALL scrape them from `otel:8889`

## Source files

- `minikube/otel/{configmap,deployment,service}.yaml`
- `minikube/prometheus/{configmap,deployment,service,persistence}.yaml`
- `minikube/zipkin/{deployment,service}.yaml`
- `minikube/grafana/{configmap,deployment,service,persistence}.yaml`
- `minikube/loki/{configmap,deployment,service,persistence}.yaml`
- `minikube/tempo/{configmap,deployment,service,persistence}.yaml`
