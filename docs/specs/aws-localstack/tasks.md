# Tasks: AWS Local Stack (LocalStack + StackPort)

> Reverse-engineered from the current repository. `[x]` = implemented as built; `[ ]` = known gap or future work.

## 1. LocalStack deployment (AWS-01, AWS-04, AWS-07)

- [x] 1.1 Create `minikube/localstack/deployment.yaml` with one replica and `Recreate` strategy.
- [x] 1.2 Pin image `localstack/localstack:3.7.0` with `IfNotPresent` pull policy.
- [x] 1.3 Set `SERVICES=sqs,sns,dynamodb,s3` and `AWS_DEFAULT_REGION=us-east-1`.
- [x] 1.4 Inject AWS credentials from Secret `aws-credentials`.
- [x] 1.5 Add liveness/readiness probes on `/_localstack/health:4566`.
- [x] 1.6 Apply the non-root security context (UID 1000, no privilege escalation).
- [x] 1.7 Set requests `512Mi/500m` and limits `1024Mi/1000m`.

## 2. LocalStack exposure (AWS-02)

- [x] 2.1 Create NodePort Service with edge port 4566 → NodePort 30002.
- [x] 2.2 Map port 4571 → NodePort 30003.
- [ ] 2.3 Remove the unused `4571`/`es` mapping or enable Elasticsearch and document it.

## 3. Initialization and state (AWS-03, AWS-05)

- [x] 3.1 Create ConfigMap `localstack-init-scripts` with `init-bucket.sh`.
- [x] 3.2 Mount the script at `/etc/localstack/init/ready.d/` with mode `0755`.
- [x] 3.3 Create PVC `localstack-claim` (500Mi) and mount it at `/var/lib/localstack`.
- [x] 3.4 Include `minikube/localstack/` in `make apply` and `make destroy`.
- [ ] 3.5 Provide a documented command (or job) to create `balance-sqs-queue` for the k6 test.
- [ ] 3.6 Consider extra init resources (SNS topic, DynamoDB table) if consumers need them.

## 4. StackPort (AWS-06)

- [x] 4.1 Create Deployment `stackport` using `davireis/stackport:latest`.
- [x] 4.2 Configure `AWS_ENDPOINT_URL=http://localstack:4566` and the AWS credentials Secret.
- [x] 4.3 Create NodePort Service on 8080 → NodePort 30006.
- [ ] 4.4 Pin the StackPort image to a version instead of `latest`.

## 5. Security (AWS-04)

- [x] 5.1 Store demo AWS keys in `minikube/localstack/secrets.yaml`.
- [ ] 5.2 Replace committed demo credentials with a local-only secret manager or documented override.
