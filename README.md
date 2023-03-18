# K8s Git SSH Server

*NOT FOR PRODUCTION USE*

This repo contains a container image and helm chart for deploying a ssh-based git server into Kubernetes for testing git-based tools such as CI/CD tools, GitOps, etc.

## Deploying

Create the following file with your desired users and repositories to create:

```yaml
# my-values.yaml
git:
  users:
  - name: <user name>
    repos:
    - /path/to/repo
    # ...
  # ...
```

Then run


```bash
helm repo add k8s-git-server https://meln5674.github.io/k8s-git-server/

helm upgrade --install k8s-git-server k8s-git-server/k8s-git-server --values my-values.yaml --wait
```

## Connecting

This chart is only intended to be connected from within the same cluster.

See the NOTES output from `helm upgrade` for the names of your secrets and and example YAMLs
