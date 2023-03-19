IMAGE_REGISTRY ?= ghcr.io
IMAGE_REPO ?= meln5674/k8s-git-server
GIT_COMMIT = $(shell git rev-parse HEAD)
CHART_VERSION = $(shell yq '.version' charts/k8s-git-server/Chart.yaml)
CHART_APP_VERSION = $(shell yq '.appVersion' charts/k8s-git-server/Chart.yaml)
IMAGE_TAG ?= $(CHART_APP_VERSION)
IMAGE ?= $(IMAGE_REGISTRY)/$(IMAGE_REPO):$(IMAGE_TAG)

KIND_CLUSTER ?= kind

all: docker-build

.PHONY: docker-build
docker-build:
	docker build -t $(IMAGE) $(DOCKER_BUILD_FLAGS) .

.PHONY: kind-load
kind-load: docker-build
	kind load docker-image --name=$(KIND_CLUSTER) $(IMAGE)

smoke-test-local: kind-load
	./test/smoke-test.sh ./charts/k8s-git-server/

smoke-test-remote:
	helm repo add k8s-git-server https://meln5674.github.io/k8s-git-server/
	helm repo update k8s-git-server
	./test/smoke-test.sh k8s-git-server/k8s-git-server $(CHART_VERSION)
	
