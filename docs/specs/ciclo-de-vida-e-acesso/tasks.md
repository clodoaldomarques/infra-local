# Tasks: Lifecycle and Access

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. Minikube lifecycle (OPS-01)

- [x] 1.1 Add `start` running `minikube start` and `minikube dashboard &`.
- [x] 1.2 Add `stop`, `status` and `dashboard` targets.
- [ ] 1.3 Document that the dashboard is launched as a background process.

## 2. Apply / destroy / reload (OPS-02, OPS-03, OPS-08)

- [x] 2.1 Add `apply` with the ten component directories in the documented order.
- [x] 2.2 Add `destroy` with the same directories and `--ignore-not-found`.
- [x] 2.3 Add `reload` as `destroy apply`.
- [x] 2.4 Keep k6, Ollama and Tempo out of the apply/destroy sets.
- [x] 2.5 Rely on the `default` namespace for all resources.
- [ ] 2.6 Add a confirmation prompt or `FORCE=1` guard for `destroy` / `reload`.
- [ ] 2.7 Verify the current kubectl context points to Minikube before applying.

## 3. Access (OPS-04)

- [x] 3.1 Define fixed NodePorts 30001–30011 in the Service manifests.
- [x] 3.2 Leave Loki and Tempo as ClusterIP-only Services.
- [x] 3.3 Document the resulting URLs in `README.md`.
- [ ] 3.4 Detect and document NodePort collisions with other local clusters.

## 4. Credentials (OPS-05, OPS-06)

- [x] 4.1 Commit base64 demo values in `mysql/secrets.yaml` and `localstack/secrets.yaml`.
- [x] 4.2 Use `admin`/`admin` for Grafana.
- [x] 4.3 Add `make encrypt pass=<value>`.
- [ ] 4.4 Replace committed demo credentials with a local override workflow.
- [ ] 4.5 Quote the `pass` argument in `make encrypt` to handle special characters.

## 5. Help and .PHONY consistency (OPS-07)

- [x] 5.1 Add `help` listing the main targets.
- [x] 5.2 List `apply`, `destroy`, `restart`, `mysql-logs` and `k6-*` in `make help`.
- [ ] 5.3 Implement or remove `restart`, `mysql-logs`, `k6-config` and `k6-destroy`.
- [ ] 5.4 Add `start`, `stop`, `status`, `dashboard`, `reload`, `encrypt`, `k6-stop` and `k6-reload` to `.PHONY` and `help`.

## 6. Documentation

- [x] 6.1 Keep `README.md` aligned with the Makefile and manifests.
- [x] 6.2 Mirror the lifecycle and access specs in `docs/specs/ciclo-de-vida-e-acesso/`.
- [ ] 6.3 Add a short "destructive operations" warning to `make help` output.
