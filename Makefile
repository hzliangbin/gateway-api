# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Enable Go modules.
export GO111MODULE=on

REGISTRY ?= gcr.io/k8s-staging-gateway-api
TAG ?= dev
COMMIT=$(shell git rev-parse --short HEAD)

DOCKER ?= docker
# TOP is the current directory where this Makefile lives.
TOP := $(dir $(firstword $(MAKEFILE_LIST)))
# ROOT is the root of the mkdocs tree.
ROOT := $(abspath $(TOP))

all: generate vet fmt verify test

# Run generators for protos, Deepcopy funcs, CRDs, and docs.
.PHONY: generate
generate:
	hack/update-codegen.sh

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Run go test against code
test:
	go test -race -cover ./...

# Install CRD's and example resources to a pre-existing cluster.
.PHONY: install
install: crd example

# Install the CRD's to a pre-existing cluster.
.PHONY: crd
crd:
	kubectl kustomize config/crd | kubectl apply -f -

# Install the example resources to a pre-existing cluster.
.PHONY: example
example:
	hack/install-examples.sh

# Remove installed CRD's and CR's.
.PHONY: uninstall
uninstall:
	hack/delete-crds.sh

# Run static analysis.
.PHONY: verify
verify:
	hack/verify-all.sh -v

# Build the documentation.
.PHONY: docs
docs:
	hack/make-docs.sh

.PHONY: build
build:
	docker build --build-arg COMMIT=$(COMMIT) --build-arg TAG=$(TAG) \
			-t $(REGISTRY)/admission-server:$(TAG) .

.PHONY: release-staging
release-staging: build
	docker push $(REGISTRY)/admission-server:$(TAG)
	docker tag $(REGISTRY)/admission-server:$(TAG) $(REGISTRY)/admission-server:latest
	docker push $(REGISTRY)/admission-server:latest

# Generate a virtualenv install, which is useful for hacking on the
# docs since it installs mkdocs and all the right dependencies.
#
# On Ubuntu, this requires the python3-venv package.
virtualenv: .venv
.venv: requirements.txt
	@echo Creating a virtualenv in $@"... "
	@python3 -m venv $@ || (rm -rf $@ && exit 1)
	@echo Installing packages in $@"... "
	@$@/bin/python3 -m pip install -q -r requirements.txt || (rm -rf $@ && exit 1)
	@echo To enter the virtualenv type \"source $@/bin/activate\",  to exit type \"deactivate\"
