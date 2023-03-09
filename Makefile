SHELL ?= /bin/bash
RUNTIME ?= podman
REPOOWNER ?= openshift-kni
IMAGENAME ?= telco-ran-tools
IMAGETAG ?= latest

all: dist

.PHONY: fmt
fmt: ## Run go fmt against code.
	@echo "Running go fmt"
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	@echo "Running go vet"
	go vet ./...

.PHONY: shellcheck
shellcheck: ## Run shellcheck
	@echo "Running shellcheck"
	hack/shellcheck.sh

.PHONY: bashate
bashate: ## Run bashate
	@echo "Running bashate"
	hack/bashate.sh

.PHONY: update-resources
update-resources: shellcheck bashate
	@echo "Updating docs/resources/boot-beauty.ign"
	@sed -i "s#base64,.*#base64,$(shell base64 -w 0 docs/resources/extract-ocp.sh)\"#" docs/resources/boot-beauty.ign
	@echo "Updating docs/resources/discovery-beauty.ign"
	@sed -i "s#base64,.*#base64,$(shell base64 -w 0 docs/resources/extract-ai.sh)\"#" docs/resources/discovery-beauty.ign
	@hack/update-docs.sh

.PHONY: check-git-tree
check-git-tree: # If generated code is added in the future, add generation dependency here
	hack/check-git-tree.sh

.PHONY: build
build: dist

.PHONY: ci-job-e2e
ci-job-e2e: test-e2e check-git-tree

.PHONY: ci-job-unit
ci-job-unit: fmt vet test-unit shellcheck bashate update-resources check-git-tree

outdir:
	mkdir -p _output || :

.PHONY: deps-update
deps-update:
	go mod tidy && go mod vendor

.PHONY: deps-clean
deps-clean:
	rm -rf vendor

.PHONY: dist
dist: binaries

.PHONY: binaries
binaries: outdir deps-update fmt vet
	# go flags are set in here
	./hack/build-binaries.sh

.PHONY: clean
clean:
	rm -rf _output

.PHONY: image
image:
	@echo "building image"
	$(RUNTIME) build -f Dockerfile -t quay.io/$(REPOOWNER)/$(IMAGENAME):$(IMAGETAG) .

.PHONY: push
push: image
	@echo "pushing image"
	$(RUNTIME) push quay.io/$(REPOOWNER)/$(IMAGENAME):$(IMAGETAG)

.PHONY: test-unit
test-unit: test-unit-cmd

.PHONY: test-unit-cmd
test-unit-cmd:
	go test ./cmd/...

.PHONY: test-e2e
test-e2e: binaries
	ginkgo test/e2e
