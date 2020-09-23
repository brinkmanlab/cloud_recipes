# cloud_recipes
Kubernetes deployment recipes for various third party cloud providers


## Generate kubeconfig for AWS

With the aws-cli installed:
```
aws eks --region 'us-west-2' update-kubeconfig --name 'Brinkman-Lab'
```

See the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) for more information.

## Dashboard

Dashboard is accessed by running `kubectl proxy` and then directing your web browser to [http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)