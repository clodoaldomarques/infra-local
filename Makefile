
apply:
	kubectl apply -f minikube/localstack/
	kubectl apply -f minikube/dynamodb-admin/
	kubectl apply -f minikube/mysql/
	kubectl apply -f minikube/ollama/
	kubectl apply -f minikube/redis/

delete:
	kubectl delete -f minikube/localstack/ --ignore-not-found
	kubectl delete -f minikube/dynamodb-admin/ --ignore-not-found
	kubectl delete -f minikube/mysql/ --ignore-not-found
	kubectl delete -f minikube/ollama/ --ignore-not-found
	kubectl delete -f minikube/redis/ --ignore-not-found