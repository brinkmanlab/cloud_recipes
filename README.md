# cloud_recipes
Kubernetes deployment recipes for various third party cloud providers

## AWS

Install the [AWS CLI tool](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html).
Ensure you are authenticating with the correct IAM user by running `aws sts get-caller-identity`. Run `aws configure` to specify the
credentials to use for deployment. The user deploying the cluster will automatically be granted admin privileges for the cluster.

Run `aws-iam-authenticator token -i <cluster name> --token-only` to get the required token for the dashboard.

Configure `kubectl` by running `aws eks --region us-west-2 update-kubeconfig --name <cluster name>`.

Refer to the Kubernetes section for the remaining information.

## Azure

## Utilities
Various Kubernetes utility modules are included in the `./util` folder.
The dashboard is included in all destinations by default.

### Dashboard

All cloud deployments include a dashboard server that provides administrative control of the cluster.
To access it, [install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and run `kubectl proxy` in a separate terminal.
Visit [here](http://localhost:8001/api/v1/namespaces/kube-system/services/https:dashboard-chart-kubernetes-dashboard:https/proxy/#/login) to
access the dashboard.

To check the state of the cluster run `kubectl describe node`.

### CVMFS CSI driver

