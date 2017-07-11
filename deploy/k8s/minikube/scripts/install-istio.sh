#!/usr/bin/env bash

set -e

(which minikube &>/dev/null) || (echo '* missing minikube, is it installed?' && exit 1)
(which kubectl &>/dev/null) || (echo '* missing kubectl, is it installed?' && exit 1)
(which docker &>/dev/null) || (echo '* missing docker; is it installed?' && exit 1)
(which mvn &>/dev/null) || (echo '* missing mvn; is it installed?' && exit 1)
(which istioctl &>/dev/null) || (echo '* missing istioctl; ensure that Istio is installed and `istioctl` is available on your PATH. More info: https://istio.io/docs/tasks/installing-istio.html' && exit 1)

RESOURCES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISTIO_PATH="$(cd "$(dirname "$(which istioctl)")/.." && pwd)"

kubectl-create-with-istio() {
    # Several hacky things here...
    # kube-inject doesn't currently support StatefulSet, so we hack output to
    # Deployment and then turn it back into StatefulSet
    # and add back the service name that is strips

    if grep -q '"kind":\s*"StatefulSet"' "$1"; then
        service_name="$(cat "$1" | sed -n 's/".*serviceName"\s*:\s*"\([^"]*\)".*,/\1/p' | sed 's/^ *//;s/ *$//')"

        cat "$1" |
        sed 's/"kind": "StatefulSet"/"kind": "Deployment"/' |
        istioctl kube-inject -f - |
        sed 's/kind: Deployment/kind: StatefulSet/' |
        sed "s/^spec:$/spec:\n  serviceName: $service_name/" |
        sed 's/status: {}//' |
        sed 's/strategy: {}//' |
        kubectl create -f -
    else
        cat "$1" |
        istioctl kube-inject -f - |
        sed 's/---$//' |
        kubectl create -f -
    fi
}

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

echo '*********************************'
echo '***  Deploying istio/addons   ***'
echo '*********************************'

kubectl apply -f "$ISTIO_PATH/install/kubernetes/istio-rbac-beta.yaml"
kubectl apply -f "$ISTIO_PATH/install/kubernetes/istio-auth.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/prometheus.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/grafana.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/servicegraph.yaml"
wait-for-pods

echo '****************************'
echo '***  Deploying cassandra ***'
echo '****************************'

kubectl create -f "$RESOURCES_PATH/cassandra"
wait-for-pods

kubectl exec cassandra-0 -- nodetool status

echo '****************************'
echo '***  Building chirper    ***'
echo '****************************'

mvn clean package docker:build
docker images

echo '**********************************'
echo '***  Deploying chirper/istio   ***'
echo '**********************************'

for file in $RESOURCES_PATH/chirper/*; do
    kubectl-create-with-istio "$file"
done
wait-for-pods

echo '**********************************'
echo '***  Deploying istio ingress   ***'
echo '**********************************'

kubectl create -f "$RESOURCES_PATH/istio"
wait-for-pods

kubectl get pods

GATEWAY_URL=$(kubectl get po -l istio=ingress -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc istio-ingress -o 'jsonpath={.spec.ports[0].nodePort}')

echo $GATEWAY_URL

#minikube service nginx-ingress
