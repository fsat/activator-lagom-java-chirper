#!/usr/bin/env bash

set -e

RESOURCES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(which minikube &>/dev/null) || (echo '* missing minikube, is it installed?' && exit 1)
(which kubectl &>/dev/null) || (echo '* missing kubectl, is it installed?' && exit 1)
(which docker &>/dev/null) || (echo '* missing docker; is it installed?' && exit 1)
(which mvn &>/dev/null) || (echo '* missing mvn; is it installed?' && exit 1)

source "$RESOURCES_PATH/scripts/istioctl-kube-inject-wrapper.sh"

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

kubectl create -f "$RESOURCES_PATH/cassandra"
wait-for-pods

kubectl exec cassandra-0 -- nodetool status

echo '*********************************'
echo '***  Deploying istio/addons   ***'
echo '*********************************'

kubectl apply -f "$ISTIO_PATH/install/kubernetes/istio-rbac-beta.yaml"
kubectl apply -f "$ISTIO_PATH/install/kubernetes/istio.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/prometheus.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/grafana.yaml"
#kubectl apply -f "$ISTIO_PATH/install/kubernetes/addons/servicegraph.yaml"
wait-for-pods

echo '****************************'
echo '***  Building chirper    ***'
echo '****************************'

(cd "$RESOURCES_PATH/../../.." && mvn clean package docker:build)

docker images

export GATEWAY_URL="$(kubectl get po -l istio=ingress -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc istio-ingress -o 'jsonpath={.spec.ports[0].nodePort}')"

echo '**********************************'
echo '***  Deploying chirper/istio   ***'
echo '**********************************'

for file in $RESOURCES_PATH/chirper/*; do
    # @TODO FIXME: This doesn't solve the problem as the ingress is still powered by envoy

    # envoy doesn't support websockets, so we need to bypass Istio proxy injection for these services
    # https://github.com/lyft/envoy/issues/319

    if (grep -q "chirp-impl\|activity-stream-impl" <<< "$file"); then
        kubectl create -f "$file"
    else
        istioctl-kube-inject "$file" | kubectl create -f -
    fi
done
wait-for-pods

kubectl get pods

echo
echo
echo "Chirper: $(minikube service --url istio-ingress | head -n 1)"
echo "Kubernetes Dashboard: $(minikube dashboard --url)"
