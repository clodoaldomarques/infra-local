# Requirements: Local AI (Ollama)

## Introduction

Reverse-engineered from `minikube/ollama/`. This domain covers the local model runtime, the setup Job that downloads and customizes a model, the shared PVC and the external access path. Ollama is deployed manually and is not part of `make apply`.

## Glossary

- **Base model**: `qwen2.5-coder:1.5b`, pulled from the Ollama registry.
- **Custom model**: `griphook`, created from the base model plus the `Modelfile` system prompt.
- **Setup Job**: `ollama-setup`, a one-shot Job with `ttlSecondsAfterFinished: 300`.

## Requirements

### Requirement: AI-01 — Deploy Ollama manually

The system SHALL keep Ollama out of `make apply` and SHALL allow explicit deployment with `kubectl apply -f minikube/ollama/`.

#### Scenario: Normal bootstrap

- **WHEN** `make apply` completes
- **THEN** no Ollama Deployment, Service, PVC or Job SHALL exist

#### Scenario: Manual deployment

- **WHEN** an operator runs `kubectl apply -f minikube/ollama/`
- **THEN** the ConfigMap, PVC, Deployment, Service and setup Job SHALL be created in the `default` namespace

### Requirement: AI-02 — Expose the model runtime

The system SHALL run Ollama with `OLLAMA_HOST=0.0.0.0` on port 11434 and expose it as `ollama:11434` and NodePort `30007`.

#### Scenario: In-cluster access

- **WHEN** a workload calls `http://ollama:11434/api/generate`
- **THEN** the system SHALL forward the request to the Ollama container

#### Scenario: Host access

- **WHEN** a client connects to `http://$(minikube ip):30007`
- **THEN** the system SHALL forward the connection to port 11434

#### Scenario: Probes

- **WHEN** readiness or liveness probes run
- **THEN** the system SHALL perform an HTTP GET on `/` at port 11434

### Requirement: AI-03 — Persist models in a shared PVC

The system SHALL mount PVC `ollama-pv-claim` (10Gi) at `/root/.ollama` in both the Deployment and the setup Job.

#### Scenario: Model setup

- **WHEN** the setup Job downloads and creates models
- **THEN** the model files SHALL be written to `ollama-pv-claim`

#### Scenario: Deployment startup

- **WHEN** the Ollama Deployment starts after the Job
- **THEN** it SHALL see the same models through the shared PVC

### Requirement: AI-04 — Download and customize the model

The system SHALL pull `qwen2.5-coder:1.5b` and create the custom model `griphook` from ConfigMap `ollama-modelfile`.

#### Scenario: Setup Job execution

- **WHEN** the Job starts
- **THEN** it SHALL start `ollama serve` in the background and wait until `ollama list` succeeds
- **AND** it SHALL run `ollama pull qwen2.5-coder:1.5b`
- **AND** it SHALL copy `/config/Modelfile` to `/tmp/Modelfile` and run `ollama create griphook -f /tmp/Modelfile`
- **AND** it SHALL print `ollama list` at the end

#### Scenario: Existing base model

- **WHEN** `qwen2.5-coder:1.5b` is already present in the PVC
- **THEN** the pull SHALL not download it again

#### Scenario: Job cleanup

- **WHEN** the Job finishes
- **THEN** the system SHALL remove it after 300 seconds

### Requirement: AI-05 — Configure the griphook system prompt

The system SHALL define `griphook` with temperature `0.1`, top_p `0.8` and a system prompt that validates business rules for `script_id` 101 and "Cash purchase" descriptions, returning only JSON with `valid` and `reason`.

#### Scenario: Regular flow with script 101

- **WHEN** the model receives `script_id=101` and `flow=regular`
- **THEN** the system prompt SHALL require expression `Amount.amount + Fee.iof`

#### Scenario: Migration flow with script 101

- **WHEN** the model receives `script_id=101` and `flow=migration`
- **THEN** the system prompt SHALL require expression `Amount.amount`

#### Scenario: Unrestricted case

- **WHEN** none of the rules apply
- **THEN** the model SHALL answer with `valid: true` and an empty reason

### Requirement: AI-06 — Reserve memory for the model runtime

The system SHALL request 4Gi and limit 5Gi of memory for the Ollama Deployment.

#### Scenario: Scheduling

- **WHEN** the Deployment is scheduled
- **THEN** the container SHALL request 4Gi memory and 1 CPU
- **AND** it SHALL be limited to 5Gi memory and 2 CPUs
