#!/usr/bin/env bash

set -e

(which minikube &>/dev/null) || (echo '* missing minikube, is it installed?' && exit 1)
(which docker &>/dev/null) || (echo '* missing docker; is it installed?' && exit 1)

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

while (kubectl get pods | grep 0/1) &>/dev/null; do sleep 1; done

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

while (kubectl get pods | grep 0/1) &>/dev/null; do sleep 1; done

echo '****************************'
echo '***  Deploying nginx   ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/nginx

while (kubectl get pods | grep 0/1) &>/dev/null; do sleep 1; done

kubectl get pods

minikube service nginx-ingress
