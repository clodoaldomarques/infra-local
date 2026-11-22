# Specs (SDD, estilo Kiro)

This directory contains **reverse-engineered specs** for Infra Local. They describe the system *as it is implemented today* by the `Makefile` and the manifests under `minikube/` — not a desired future state.

## Structure

```text
docs/
├── README.md
└── specs/
    ├── aws-localstack/            # LocalStack + StackPort
    │   ├── requirements.md        # WHAT / WHY (EARS scenarios)
    │   ├── design.md              # HOW (components, interfaces, decisions)
    │   └── tasks.md               # as-built checklist + open gaps
    ├── persistencia-e-cache/      # MySQL + Redis
    ├── observabilidade/           # OTel + Prometheus + Zipkin + Grafana + Loki/Tempo
    ├── k6-carga/                  # k6 load test
    ├── ollama-ia/                 # Ollama + setup Job
    └── ciclo-de-vida-e-acesso/    # Makefile, ports, PVCs, credentials
```

## Conventions

- **`requirements.md`** uses EARS-style acceptance scenarios:
  - `WHEN <event>` / `GIVEN <precondition>` → `THE SYSTEM SHALL <observable behavior>`.
  - Every requirement has a stable ID (e.g. `OBS-03`) that tasks and designs refer to.
- **`design.md`** documents the current design and the rationale inferred from the manifests. It explicitly lists deviations and open gaps.
- **`tasks.md`** is a reverse-engineered checklist. `[x]` means the item already exists in the repo; `[ ]` means a known gap or unfinished work.

## How to use these specs to study SDD

1. Read this index, then one domain's `requirements.md` → `design.md` → `tasks.md`.
2. Notice how each requirement ID is traceable to a task and to a source manifest.
3. To practice the forward flow, pick an open `[ ]` task (or invent a feature): write the requirement first, then the design, then the tasks, and only then touch the manifests.
4. When a manifest changes, update the matching spec by hand — there is no generator.

## Source of truth

These specs were derived from:

- `Makefile` — lifecycle targets and their exact `kubectl` invocations
- `minikube/**/*.yaml` — Deployments, Services, PVCs, ConfigMaps, Secrets
- `minikube/k6/configmap.yaml` — embedded `script.js`
- `minikube/ollama/configmap.yaml` — embedded `Modelfile`
- `README.md` — human-facing summary (kept in sync manually)

## Known as-built gaps captured in the specs

- Tempo manifests exist but `make apply` never deploys them.
- Loki is deployed but no log pipeline feeds it.
- Zipkin uses in-memory storage; traces do not survive a restart.
- k6 depends on a `ledger-config` Service and an SQS queue that this repo does not create.
- `make help` advertises targets that are not defined (`restart`, `mysql-logs`, `k6-config`, `k6-destroy`).
- Credentials are committed base64 demo values, not a secret-management solution.
