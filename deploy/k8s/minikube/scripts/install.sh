#!/usr/bin/env bash

set -e

RESOURCES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(which minikube &>/dev/null) || (echo '* missing minikube, is it installed?' && exit 1)
(which kubectl &>/dev/null) || (echo '* missing kubectl, is it installed?' && exit 1)
(which docker &>/dev/null) || (echo '* missing docker; is it installed?' && exit 1)
(which mvn &>/dev/null) || (echo '* missing mvn; is it installed?' && exit 1)

wait-for-pods() {
    echo -n 'waiting...'
    while (kubectl get pods 2>&1 | grep '0/\|1/2\|No resources') &>/dev/null; do echo -n '.' && sleep 1; done
    echo
}
echo '****************************'
echo '***  Resetting minikube  ***'
echo '****************************'

(minikube delete || true) &>/dev/null

minikube start --memory 8192

eval $(minikube docker-env)

echo '****************************'
echo '***  Deploying cassandra ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/cassandra
wait-for-pods

kubectl exec cassandra-0 -- nodetool status

echo '****************************'
echo '***  Building chirper    ***'
echo '****************************'

(cd "$RESOURCES_PATH/../../.." && mvn clean package docker:build)

docker images

echo '****************************'
echo '***  Deploying chirper   ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/chirper
wait-for-pods

echo '****************************'
echo '***  Deploying nginx   ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/nginx
wait-for-pods

kubectl get pods

echo
echo
echo "Chirper UI: $(minikube service --url nginx-ingress)"
echo "Kubernetes Dashboard: $(minikube dashboard --url)"
