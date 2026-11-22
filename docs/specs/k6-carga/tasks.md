# Tasks: k6 Load Test

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. Lifecycle targets (K6-01)

- [x] 1.1 Add `k6-run` applying `configmap.yaml` + `deployment.yaml`, deleting and recreating Job `k6-load-test`.
- [x] 1.2 Add `k6-logs` following `job/k6-load-test`.
- [x] 1.3 Add `k6-stop` deleting all resources under `minikube/k6/`.
- [x] 1.4 Add `k6-reload` as `k6-stop` + `k6-run`.
- [x] 1.5 Keep k6 out of `make apply` and `make destroy`.
- [ ] 1.6 Remove the undefined `k6-config` and `k6-destroy` entries from `.PHONY` and `make help`, or implement them.

## 2. Configuration (K6-07)

- [x] 2.1 Create ConfigMap `k6-env` with AWS endpoint/region/credentials, queue URL, `LEDGER_CONFIG_URL` and test IDs.
- [x] 2.2 Create ConfigMap `k6-script` with the embedded `script.js`.
- [x] 2.3 Set OTLP output env vars (`K6_OUT`, endpoint, insecure, prefix `k6_`) on both Deployment and Job.
- [ ] 2.4 Move AWS credentials from the ConfigMap to a Secret.

## 3. Script behavior (K6-02, K6-03, K6-04)

- [x] 3.1 Implement `setup()` with POST to `/v1/ledger/org/activate` and the "already activated" case.
- [x] 3.2 Build the transaction message with org, account, amount, authorization, program, transaction type and tax.
- [x] 3.3 Publish to SQS via `SQSClient` and record errors, duration and sent count.
- [x] 3.4 Define stages for 10 and 25 VUs and the three thresholds.
- [ ] 3.5 Vendor or pin the jslib SQS module instead of fetching it at runtime.
- [ ] 3.6 Add a local mock of `ledger-config` so the test can run without external projects.

## 4. Kubernetes resources (K6-05, K6-06)

- [x] 4.1 Create Deployment `k6` running the script with `grafana/k6:latest`.
- [x] 4.2 Create Job `k6-load-test` with `restartPolicy: Never` and `backoffLimit: 1`.
- [x] 4.3 Mount `k6-script` at `/scripts` and inject `k6-env` via `envFrom`.
- [x] 4.4 Set requests `256Mi/250m` and limits `512Mi/500m`.
- [ ] 4.5 Decide between Job-only or Deployment-only execution to avoid duplicate load generation.
- [ ] 4.6 Add `ttlSecondsAfterFinished` to the Job.

## 5. Prerequisites and documentation

- [x] 5.1 Document the prerequisites in `README.md` and in `docs/specs/aws-localstack/`.
- [ ] 5.2 Provide a helper target that creates `balance-sqs-queue` before `k6-run`.
- [ ] 5.3 Document how to expose a `ledger-config` Service for local runs.
