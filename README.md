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
    - path: /path/to/repo
    # ...
  # ...
```

Then run


```bash
helm repo add k8s-git-server https://meln5674.github.io/k8s-git-server/

helm upgrade --install k8s-git-server k8s-git-server/k8s-git-server --values my-values.yaml --wait
```

### Pre-populate repositories

To pre-populate your repositories from a volume (such as a ConfigMap or PersistentVolumeClaim), add a "source" section to the repository configuration

```yaml
# my-values.yaml
git:
  users:
  - name: <user name>
    repos:
    - path: /path/to/repo
      source:
        volume:
          persistentVolumeClaim:
            name: my-pvc
        # This is optional, if not specified, it will populate from the entire PVC.
        # You can use any field from pod.spec.containers.*.volumeMounts.*, not just subPath
        volumeMount:
          subPath: path/within/pvc
        # This is optional. Tar is used to copy the directory contents, allow "filtering" using flags like --exclude.
        tarFlags: [--exclude='undesirable-directory/**']
  # ...
```

These repos will be re-created on each `helm upgrade`. If you wish to persist changes to these repos, se

```yaml
# my-values.yaml
persistence:
  enabled: true
```

and omit the `git` section in subsequent `helm upgrade` commands.

### SVN

SVN is also supported, to specify a repo is an SVN repo, set `type: svn`

```yaml
# my-values.yaml
git:
  users:
  - name: <user name>
    repos:
    - path: /path/to/repo
```
## Connecting

This chart is only intended to be connected from within the same cluster. Secrets will be created containing SSH key pairs and a known_hosts file to use.

See the NOTES output from `helm upgrade` for the names of your secrets and and example YAMLs
