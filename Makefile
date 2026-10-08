SHELL := /bin/bash

MINIKUBE_PROFILE ?= minikube
OVERLAY          ?= k8s/overlays/dev
IMAGE            ?= kubernetes-challenge:1.0.0
NAMESPACE        ?= hello

export MINIKUBE_PROFILE OVERLAY IMAGE NAMESPACE

.PHONY: help
help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install:         ## Install npm dependencies
	npm ci

.PHONY: lint
lint:            ## Run eslint
	npm run lint

.PHONY: test
test:            ## Run unit tests
	npm test

.PHONY: build
build:           ## Build the image directly inside minikube
	./scripts/build-image.sh

.PHONY: deploy
deploy:          ## Apply the kustomize overlay
	./scripts/deploy.sh

.PHONY: verify
verify:          ## Curl minikube and assert the greeting
	./scripts/verify.sh

.PHONY: up
up:              ## Full local setup: start minikube, build, deploy, verify
	./scripts/bootstrap.sh

.PHONY: down
down:            ## Delete the deployed resources
	./scripts/teardown.sh

.PHONY: logs
logs:            ## Tail the application logs
	kubectl -n $(NAMESPACE) logs -l app.kubernetes.io/name=hello -f --tail=50

.PHONY: port-forward
port-forward:    ## Forward the Service to localhost:8080
	kubectl -n $(NAMESPACE) port-forward svc/hello 8080:80
