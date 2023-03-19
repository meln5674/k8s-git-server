#!/bin/bash -xeu

CHART=$1
VERSION=${2:-}

FLAGS=( k8s-git-server "${CHART}" --values test/values.yaml )
if [ -n "${VERSION}" ]; then
    FLAGS+=( --version="${VERSION}" )
fi

for x in $(seq 10); do
  helm repo update --debug
  if helm template "${FLAGS[@]}" ; then
      break
  fi
  echo 'Waiting and retrying'
  sleep 60
done

FLAGS+=( --wait --debug --install )

kubectl apply -f test/configmap.yaml

kubectl delete job k8s-git-server-push || true
( while ! kubectl logs -f job/k8s-git-server-push ; do sleep 2; done ) &

helm upgrade "${FLAGS[@]}"

wait || true

(while ! kubectl logs -f k8s-git-server-test-connection ; do sleep 2; done) &
helm test k8s-git-server --debug

wait || true
