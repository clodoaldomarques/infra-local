# Tasks: Local AI (Ollama)

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. Manual lifecycle (AI-01)

- [x] 1.1 Keep `minikube/ollama/` out of `make apply` and `make destroy`.
- [x] 1.2 Document `kubectl apply -f minikube/ollama/` in `README.md`.
- [ ] 1.3 Add optional Make targets (`ollama-apply`, `ollama-logs`, `ollama-stop`) for consistency with k6.

## 2. Runtime and exposure (AI-02, AI-06)

- [x] 2.1 Create Deployment `ollama` with `OLLAMA_HOST=0.0.0.0`.
- [x] 2.2 Expose container port 11434 and NodePort 30007.
- [x] 2.3 Add readiness/liveness probes on `/`.
- [x] 2.4 Set requests 4Gi/1 CPU and limits 5Gi/2 CPUs.
- [x] 2.5 Use `Recreate` strategy for the single replica.
- [ ] 2.6 Pin the Ollama image to a specific version.

## 3. Persistence (AI-03)

- [x] 3.1 Create PVC `ollama-pv-claim` (10Gi).
- [x] 3.2 Mount it at `/root/.ollama` in the Deployment.
- [x] 3.3 Mount the same PVC in the setup Job.
- [ ] 3.4 Add a backup/cleanup procedure for downloaded models.

## 4. Model setup (AI-04)

- [x] 4.1 Create Job `ollama-setup` with `ttlSecondsAfterFinished: 300` and `restartPolicy: OnFailure`.
- [x] 4.2 Start `ollama serve` in the background and wait for `ollama list`.
- [x] 4.3 Pull `qwen2.5-coder:1.5b`.
- [x] 4.4 Copy the ConfigMap `Modelfile` to `/tmp/Modelfile`.
- [x] 4.5 Run `ollama create griphook -f /tmp/Modelfile`.
- [x] 4.6 Print available models with `ollama list`.
- [ ] 4.7 Add an init container or gate so the Deployment starts only after `griphook` exists.

## 5. Prompt (AI-05)

- [x] 5.1 Create ConfigMap `ollama-modelfile` with `FROM qwen2.5-coder:1.5b`.
- [x] 5.2 Set `temperature 0.1` and `top_p 0.8`.
- [x] 5.3 Define the business-rule validation system prompt with JSON-only output.
- [x] 5.4 Include the two worked examples in the prompt.
- [ ] 5.5 Add a small evaluation set to validate the prompt output format automatically.
