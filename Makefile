.PHONY: help apply destroy restart mysql-logs

help:
	@echo "Targets disponíveis:"
	@echo "  apply       - Aplica todos os recursos no minikube"
	@echo "  destroy     - Remove todos os recursos definidos"
	@echo "  restart     - destroy + apply"
	@echo "  mysql-logs  - Mostra logs do pod MySQL"

encrypt:
	echo -n $(pass) | base64 

apply:
	kubectl apply -f minikube/localstack/
	kubectl apply -f minikube/stackport/
	kubectl apply -f minikube/mysql/
	kubectl apply -f minikube/ollama/
	kubectl apply -f minikube/redis/
	kubectl apply -f minikube/collector/
	kubectl apply -f minikube/loki/
	kubectl apply -f minikube/tempo/
	kubectl apply -f minikube/prometheus/
	kubectl apply -f minikube/grafana/

destroy:
	kubectl delete -f minikube/localstack/ --ignore-not-found
	kubectl delete -f minikube/stackport/ --ignore-not-found
	kubectl delete -f minikube/mysql/ --ignore-not-found
	kubectl delete -f minikube/ollama/ --ignore-not-found
	kubectl delete -f minikube/redis/ --ignore-not-found
	kubectl delete -f minikube/collector/ --ignore-not-found
	kubectl delete -f minikube/loki/ --ignore-not-found
	kubectl delete -f minikube/tempo/ --ignore-not-found
	kubectl delete -f minikube/prometheus/ --ignore-not-found
	kubectl delete -f minikube/grafana/ --ignore-not-found

restart: destroy apply

mysql-logs:
	kubectl logs -f deployment/mysql-deployment