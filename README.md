# cloud_recipes
Kubernetes deployment recipes for various third party cloud providers


## Generate kubeconfig for AWS

With the aws-cli installed:
```
aws eks --region 'us-west-2' update-kubeconfig --name 'Brinkman-Lab'
```

See the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) for more information.