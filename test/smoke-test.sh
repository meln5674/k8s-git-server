#!/bin/bash -xeu

CHART=$1
VERSION=${2:-}

FLAGS=( --install k8s-git-server "${CHART}"  )
if [ -n "${VERSION}" ]; then
    FLAGS+=( --version="${version}" )
fi
FLAGS+=( --values test/values.yaml  --wait --debug )

kubectl apply -f test/configmap.yaml

for x in $(seq 10); do
  helm repo update --debug
  kubectl delete job k8s-git-server-push || true
  ( while ! kubectl logs -f job/k8s-git-server-push ; do sleep 2; done ) &
  if helm upgrade "${FLAGS[@]}" ; then
    break
  fi
  wait || true
  echo 'Waiting and retrying'
  sleep 60
done
helm test k8s-git-server --debug &
kubectl logs -f k8s-git-server-test-connection
wait
