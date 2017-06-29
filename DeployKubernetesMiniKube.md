Setup docker env

```
eval $(minikube docker-env)
```

# Deploy Cassandra

Based on https://github.com/kubernetes/kubernetes/tree/master/examples/storage/cassandra

## Setup

Pull the Cassandra docker image.

```
docker pull gcr.io/google-samples/cassandra:v12
```

## Declare Cassandra endpoints

Create Service to expose Cassandra endpoints.

```
kubectl create -f deploy/k8/minikube/cassandra/cassandra-service.yaml
```

Observe the created Service.

```
kubectl get svc cassandra
```

## Create Cassandra ring

Since we're using minikube:

* Only 1 instance.
* No persistent volume.

```
kubectl create -f deploy/k8/minikube/cassandra/cassandra-statefulset.yaml
```

Observe the created StatefulSet.

```
kubectl get statefulset cassandra
```

## Check Cassandra running

Cassandra should be running now.

```
kubectl get pods -l="app=cassandra"
```

Example output:

```
NAME          READY     STATUS    RESTARTS   AGE
cassandra-0   1/1       Running   0          1m
```

Run Cassandra `nodetool`.

```
kubectl exec cassandra-0 -- nodetool status
```

Example output:

```
Datacenter: DC1-K8Demo
======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.17.0.5  99.45 KiB  32           100.0%            446361b8-d005-4525-8830-04d23a43d6aa  Rack1-K8Demo
```
