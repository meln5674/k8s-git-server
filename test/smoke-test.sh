#!/bin/bash -xeu

CHART=$1
VERSION=${2:-}
IMAGE_TAG=${3:-${VERSION}"

CHART_REPO=${CHART_REPO:-k8s-git-server}
IMAGE_REPO=${IMAGE_REPO:-ghcr.io/meln5674/k8s-git-server}

FLAGS=( "${CHART}" --values test/values.yaml --set image.repository="${IMAGE_REPO}" --set image.tag="${IMAGE_TAG}" )

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

DEFER='echo'

touch ./test/.running
DEFER="${DEFER}; rm ./test/.running; kubectl rollout restart deploy/k8s-git-server||true"
trap "${DEFER}" EXIT


while [ -f ./test/.running ] && ! kubectl logs -f job/k8s-git-server-push ; do sleep 2; done &
job_logs_pid=$!
DEFER="${DEFER}; kill $job_logs_pid||true"
trap "${DEFER}" EXIT
while [ -f ./test/.running ] && ! kubectl logs -f deploy/k8s-git-server ; do echo server logs exited; sleep 2; done &
server_logs_pid=$!
DEFER="${DEFER}; echo killing server logs; kill -sINT $server_logs_pid||true"
trap "${DEFER}" EXIT
kubectl get pods -w &
watch_pods_pid=$!
DEFER="${DEFER}; kill $watch_pods_pid||true"
trap "${DEFER}" EXIT

for x in 1 2; do
    helm upgrade "${FLAGS[@]}"
    
    while [ -f ./test/.running ] && ! kubectl logs -f k8s-git-server-test-connection ; do sleep 2; done &
    test_logs_pid=$!
    DEFER="${DEFER}; kill $test_logs_pid||true"
    trap "${DEFER}" EXIT
    helm test k8s-git-server --debug
    kill $test_logs_pid||true
done
