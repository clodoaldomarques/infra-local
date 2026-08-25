# Infra Local

> Reusable local cloud-native infrastructure for development and testing with Minikube, Kubernetes, AWS-compatible services and observability tools.

## Overview

Infra Local is a reusable local development environment designed to centralize shared infrastructure resources used by backend services and distributed applications.

The project provides a Kubernetes-based development environment running on Minikube, bringing together databases, messaging infrastructure, AWS-compatible services, observability components, API mocking and local AI infrastructure.

The main goal is to avoid duplicating infrastructure configuration across individual application repositories and provide a consistent local environment for developing and testing distributed systems.

## Architecture

The environment is built around Minikube and Kubernetes.

```text
                         ┌─────────────────────────┐
                         │        Minikube         │
                         │                         │
                         │       Kubernetes        │
                         └────────────┬────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
 ┌──────────────┐             ┌──────────────┐              ┌──────────────┐
 │  Persistence │             │  Messaging   │              │ AWS Services │
 │              │             │              │              │              │
 │    MySQL     │             │    Redis     │              │  LocalStack  │
 └──────────────┘             └──────────────┘              └──────────────┘
        │                             │                             │
        └─────────────────────────────┼─────────────────────────────┘
                                      │
                                      ▼
                           ┌──────────────────────┐
                           │    Observability     │
                           │                      │
                           │ OpenTelemetry        │
                           │ Prometheus           │
                           │ Zipkin               │
                           │ Grafana              │
                           └──────────────────────┘

                           ┌──────────────────────┐
                           │   Development Tools  │
                           │                      │
                           │ MockServer            │
                           │ StackPort             │
                           │ Ollama                │
                           └──────────────────────┘
```

## Infrastructure Components

The Minikube environment currently provides the following components:

| Component | Purpose |
|---|---|
| Minikube | Local Kubernetes cluster |
| LocalStack | AWS-compatible local services |
| MySQL | Relational database |
| Redis | In-memory data store |
| OpenTelemetry Collector | Telemetry collection |
| Prometheus | Metrics collection |
| Zipkin | Distributed tracing |
| Grafana | Observability dashboards |
| MockServer | HTTP service mocking |
| Ollama | Local AI model runtime |
| StackPort | Local infrastructure access |

## Kubernetes Resources

All Kubernetes resources are organized under the `minikube/` directory.

```text
minikube/
├── grafana/
├── localstack/
├── mockserver/
├── mysql/
├── ollama/
├── otel/
├── prometheus/
├── redis/
├── stackport/
└── zipkin/
```

This organization keeps each infrastructure component isolated and allows individual resources to be managed independently when necessary.

## LocalStack

LocalStack provides AWS-compatible services inside the local Kubernetes environment.

This allows backend services to interact with AWS APIs during development without requiring an external AWS environment.

The approach is particularly useful for applications using services such as:

- Amazon SQS
- Amazon SNS
- Other AWS-compatible APIs

The exact AWS services enabled by the environment depend on the corresponding LocalStack configuration.

## Observability Stack

The environment provides a local observability stack composed of:

```text
                    Application
                         │
                         │
                OpenTelemetry SDK
                         │
                         ▼
                ┌─────────────────┐
                │ OpenTelemetry   │
                │    Collector    │
                └────────┬────────┘
                         │
                  ┌──────┴───────┐
                  │              │
                  ▼              ▼
             Prometheus        Zipkin
                  │              │
                  │              │
                  └──────┬───────┘
                         │
                         ▼
                     Grafana
```

This allows local services to be developed with observability enabled from the beginning rather than adding telemetry only after deployment.

## Local AI

The Docker Compose environment also provides Ollama for running local AI models.

The current configuration:

- Exposes Ollama on port `11434`
- Persists model data using a Docker volume
- Configures Ollama to listen on all interfaces
- Uses a startup command to pull `qwen2.5-coder:1.5b`
- Provides a container health check

This makes the environment suitable for experimenting with local AI-assisted development and applications that require an OpenAI-compatible/local model runtime.

## Infrastructure Automation

A `Makefile` provides a simple interface for managing the complete environment.

### Available commands

```bash
make help
```

### Start Minikube

```bash
make start
```

This starts Minikube and opens the Kubernetes dashboard.

### Stop Minikube

```bash
make stop
```

### Apply infrastructure

```bash
make apply
```

This applies the Kubernetes resources for:

- LocalStack
- StackPort
- MySQL
- Redis
- OpenTelemetry
- Prometheus
- Zipkin
- MockServer
- Grafana

### Destroy infrastructure

```bash
make destroy
```

Removes the Kubernetes resources managed by the project.

### Reload infrastructure

```bash
make reload
```

Equivalent to:

```text
destroy → apply
```

### Start Docker Compose services

```bash
make up
```

### Stop Docker Compose services

```bash
make down
```

The `down` target also removes Docker Compose volumes.

## Getting Started

### Requirements

- Docker
- Minikube
- kubectl
- Make

### Clone

```bash
git clone https://github.com/clodoaldomarques/infra-local.git
cd infra-local
```

### Start the Kubernetes environment

```bash
make start
```

### Deploy the infrastructure

```bash
make apply
```

After deployment, verify the Kubernetes resources:

```bash
kubectl get pods -A
```

Check the services:

```bash
kubectl get services -A
```

## Docker Compose

Some local infrastructure can also be started independently using Docker Compose.

Start the Compose environment:

```bash
make up
```

Stop it:

```bash
make down
```

The current Compose configuration provides the local Ollama runtime with persistent model storage.

## Design Goals

The project was created around the following principles:

- **Centralization** — shared infrastructure should not be duplicated across application repositories.
- **Reproducibility** — developers should be able to recreate the same local environment.
- **Automation** — infrastructure lifecycle should be executable through simple commands.
- **Isolation** — each infrastructure component should have its own Kubernetes resources.
- **Cloud-native development** — applications should be developed against infrastructure patterns similar to those used in production.
- **Observability by default** — tracing and metrics should be available during local development.
- **Local-first experimentation** — cloud services and AI infrastructure should be available without requiring external environments.

## Use Cases

Infra Local is particularly useful for developing and testing:

- Go backend services
- Microservices
- Event-driven applications
- AWS integrations
- Asynchronous workers
- Distributed systems
- REST APIs
- Observability instrumentation
- Kubernetes workloads
- Local AI integrations

## Project Structure

```text
infra-local/
│
├── minikube/
│   ├── grafana/
│   ├── localstack/
│   ├── mockserver/
│   ├── mysql/
│   ├── ollama/
│   ├── otel/
│   ├── prometheus/
│   ├── redis/
│   ├── stackport/
│   └── zipkin/
│
├── docker-compose.yaml
├── Makefile
└── README.md
```

## Engineering Concepts

This project demonstrates practical experience with:

- Kubernetes
- Minikube
- Docker
- Infrastructure automation
- Local cloud development
- AWS service emulation
- Observability
- Distributed tracing
- Metrics collection
- Service mocking
- Infrastructure standardization
- Local AI infrastructure

## Relationship with the Ledger Projects

This repository acts as shared infrastructure for local development and can support the other backend projects in the Ledger ecosystem.

```text
                    ┌─────────────────────┐
                    │    Infra Local      │
                    │                     │
                    │     Minikube        │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
   │   Ledger    │      │   Ledger    │      │   Ledger    │
   │   Events    │      │   Worker    │      │   Config    │
   └─────────────┘      └─────────────┘      └─────────────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               │
                               ▼
                  Shared local infrastructure
```

This separation allows application repositories to focus on business and application logic while infrastructure is maintained independently.

## Project Status

This project is part of my backend engineering portfolio and serves as a reusable local infrastructure environment for experimenting with cloud-native applications, distributed systems, observability and Kubernetes.

It is intentionally designed for local development and experimentation rather than production deployment.

## Author

**Clodoaldo Marques**

Backend Software Engineer focused on Go, Microservices, Distributed Systems and Cloud-Native architectures.

- GitHub: https://github.com/clodoaldomarques
- LinkedIn: https://www.linkedin.com/in/clodoaldomarques/