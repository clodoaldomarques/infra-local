.PHONY: help apply destroy restart mysql-logs k6-config k6-run k6-logs k6-destroy

help:
	@echo "Targets disponíveis:"
	@echo "  apply       - Aplica todos os recursos no minikube"
	@echo "  destroy     - Remove todos os recursos definidos"
	@echo "  restart     - destroy + apply"
	@echo "  mysql-logs  - Mostra logs do pod MySQL"
	@echo "  k6-config   - Aplica a configuração do teste k6"
	@echo "  k6-run      - Inicia o Job de teste de carga k6"
	@echo "  k6-logs     - Acompanha os logs do teste k6"
	@echo "  k6-destroy  - Remove os recursos do teste k6"



encrypt:
	echo -n $(pass) | base64 

start: 
	minikube start
	minikube dashboard &

stop: 
	minikube stop

apply:
	kubectl apply -f minikube/localstack/
	kubectl apply -f minikube/stackport/
	kubectl apply -f minikube/mysql/
	kubectl apply -f minikube/redis/
	kubectl apply -f minikube/otel/
	kubectl apply -f minikube/prometheus/
	kubectl apply -f minikube/zipkin/
	kubectl apply -f minikube/mockserver/
	kubectl apply -f minikube/grafana/
	kubectl apply -f minikube/k6/


destroy:
	kubectl delete -f minikube/localstack/ --ignore-not-found
	kubectl delete -f minikube/stackport/ --ignore-not-found
	kubectl delete -f minikube/mysql/ --ignore-not-found
	kubectl delete -f minikube/redis/ --ignore-not-found
	kubectl delete -f minikube/otel/ --ignore-not-found
	kubectl delete -f minikube/prometheus/ --ignore-not-found
	kubectl delete -f minikube/zipkin/ --ignore-not-found
	kubectl delete -f minikube/mockserver/ --ignore-not-found
	kubectl delete -f minikube/grafana/ --ignore-not-found

reload: destroy apply


k6-apply:
	kubectl apply -f minikube/k6/

k6-config:
	kubectl apply -f minikube/k6/configmap.yaml

k6-run: k6-config
	kubectl delete job k6-load-test --ignore-not-found
	kubectl apply -f minikube/k6/job.yaml

k6-logs:
	kubectl logs -f job/k6-load-test

k6-destroy:
	kubectl delete -f minikube/k6/ --ignore-not-found

## docker
up:
	docker compose up -d

down:
	docker compose down -v