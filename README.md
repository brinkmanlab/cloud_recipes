# Cloud Recipes
Container orchestration deployment recipes for various third party cloud providers

## AWS EKS

See [./aws/README.md](aws/README.md)

## Azure
TODO

## Google Cloud
TODO

## Kubernetes
To check the state of the cluster run `kubectl describe node`.
To restart a deployment run `kubectl rollout restart -n <namespace> deployment <deployment name>`.

## Utilities
Various utility modules are included in the `./util` folder.
The dashboard is included in all destinations by default.

### Dashboard

All cloud deployments include a dashboard server that provides administrative control of the cluster.
To access it, [install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and run `kubectl proxy` in a separate terminal.
Visit [here](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login) to
access the dashboard.

### CVMFS CSI driver for Kubernetes

A CVMFS CSI driver is deployable using the `./util/k8s/cvmfs` terraform module. It outputs a storage class name to be used
in a Kubernetes persistent volume claim definition.