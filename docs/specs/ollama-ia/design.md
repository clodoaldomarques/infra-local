# Design: Local AI (Ollama)

## Overview

Ollama runs as a single Deployment backed by a shared PVC. A separate setup Job runs once to download a small coder model and derive a domain-specific JSON validator named `griphook`. Both resources are applied manually, so the default `make apply` footprint stays small.

## Components and interfaces

| Resource | Source | Image | Notes |
|---|---|---|---|
| Deployment `ollama` | `minikube/ollama/deployment.yaml` | `ollama/ollama:latest` | `OLLAMA_HOST=0.0.0.0`, port 11434 |
| Service `ollama` | `minikube/ollama/service.yaml` | — | NodePort 30007 |
| PVC `ollama-pv-claim` | `minikube/ollama/persistence.yaml` | — | 10Gi, ReadWriteOnce |
| Job `ollama-setup` | `minikube/ollama/job.yaml` | `ollama/ollama:latest` | TTL 300s, `restartPolicy: OnFailure` |
| ConfigMap `ollama-modelfile` | `minikube/ollama/configmap.yaml` | — | `Modelfile` for `griphook` |

## Setup sequence

```text
Job starts ─▶ ollama serve (background)
          ─▶ wait for `ollama list`
          ─▶ ollama pull qwen2.5-coder:1.5b
          ─▶ cp /config/Modelfile /tmp/Modelfile
          ─▶ ollama create griphook -f /tmp/Modelfile
          ─▶ ollama list
          ─▶ Job finishes (deleted after 300s)
```

## Modelfile

- `FROM qwen2.5-coder:1.5b`
- `PARAMETER temperature 0.1`, `PARAMETER top_p 0.8`
- `SYSTEM`: business-rules validator for `description` + `scripts[]` JSON:
  - `script_id=101` + `regular` → `Amount.amount + Fee.iof`
  - `script_id=101` + `migration` → `Amount.amount`
  - "Cash purchase" descriptions follow the same regular/migration split
  - all other cases valid
  - response format: `{"valid": true/false, "reason": "short explanation"}`

## Resource profile

| Setting | Value |
|---|---|
| Memory request / limit | 4Gi / 5Gi |
| CPU request / limit | 1 / 2 |
| Storage | 10Gi PVC at `/root/.ollama` |
| Strategy | `Recreate` |
| Probes | HTTP GET `/` on 11434 |

## Decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| Manual deployment | Large PVC + model download are expensive for every bootstrap | Requires an extra explicit command |
| Shared PVC between Job and Deployment | Models created by the Job are immediately usable | Both must use the same mount path |
| Small 1.5b base model | Runs on a typical Minikube VM | Limited reasoning capability |
| Domain-specific system prompt | Demonstrates an SDD/AI-assisted validation use case | Prompt is hard-coded in a ConfigMap |
| Unpinned `ollama/ollama:latest` | Always current image | Non-reproducible model runtime |

## Verification

```bash
kubectl apply -f minikube/ollama/
kubectl logs -f job/ollama-setup
kubectl get deploy,svc,pvc -l com.job.service=ollama
kubectl exec deploy/ollama -- ollama list
curl http://$(minikube ip):30007/api/tags
```

## Gaps / open issues

- No readiness gate makes the Deployment wait for the setup Job; requests before the Job finishes may see no models (AI-04).
- Image is unpinned (`latest`), and the model tag is not pinned to a digest.
- No GPU resource requests; inference uses CPU only.
- The setup Job has no explicit failure handling beyond `restartPolicy: OnFailure`.
- `make destroy` / `make reload` do not remove Ollama resources; cleanup is manual.
