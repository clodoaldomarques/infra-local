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
	kubectl apply -f minikube/dynamodb-admin/
	kubectl apply -f minikube/stackport/
	kubectl apply -f minikube/mysql/
	kubectl apply -f minikube/ollama/
	kubectl apply -f minikube/redis/

destroy:
	kubectl delete -f minikube/localstack/ --ignore-not-found
	kubectl delete -f minikube/dynamodb-admin/ --ignore-not-found
	kubectl delete -f minikube/stackport/ --ignore-not-found
	kubectl delete -f minikube/mysql/ --ignore-not-found
	kubectl delete -f minikube/ollama/ --ignore-not-found
	kubectl delete -f minikube/redis/ --ignore-not-found

restart: destroy apply

mysql-logs:
	kubectl logs -f deployment/mysql-deployment