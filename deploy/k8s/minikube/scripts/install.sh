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

# todo wait until stabilized

echo '****************************'
echo '***  Building chirper    ***'
echo '****************************'

mvn clean package docker:build

echo '****************************'
echo '***  Deploying chirper   ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/chirper

# todo wait until stabilized

echo '****************************'
echo '***  Deploying nginx   ***'
echo '****************************'

kubectl create -f deploy/k8s/minikube/nginx

# todo wait until stabilized

kubectl get pods

minikube service nginx-ingress
