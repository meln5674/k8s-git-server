#!/bin/bash -xeu

CHART=$1
VERSION=${2:-}

CHART_REPO=${CHART_REPO:-k8s-git-server}
IMAGE_REPO=${IMAGE_REPO:-ghcr.io/meln5674/k8s-git-server}

FLAGS=( "${CHART}" --values test/values.yaml --set image.repository="${IMAGE_REPO}" --set image.tag="${VERSION}" )

if [ -z "${VERSION}" ]; then
    helm lint "${FLAGS[@]}"
else
    FLAGS+=( --version="${VERSION}" )

    for x in $(seq 10); do
      helm repo update --debug "${CHART_REPO}"
      if helm template "${FLAGS[@]}" ; then
          break
      fi
      echo 'Waiting and retrying'
      sleep 60
    done
fi



FLAGS=( k8s-git-server  "${FLAGS[@]}" )
helm template "${FLAGS[@]}" >/dev/null

FLAGS+=( --wait --debug --install )

kubectl apply -f test/configmap.yaml

kubectl delete job k8s-git-server-push || true
( while ! kubectl logs -f job/k8s-git-server-push ; do sleep 2; done ) &

helm upgrade "${FLAGS[@]}"

wait || true

(while ! kubectl logs -f k8s-git-server-test-connection ; do sleep 2; done) &
helm test k8s-git-server --debug

wait || true
