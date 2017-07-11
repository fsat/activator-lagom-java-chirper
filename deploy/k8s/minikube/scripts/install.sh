#!/usr/bin/env bash

set -e

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

mvn clean package docker:build

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

minikube service nginx-ingress
