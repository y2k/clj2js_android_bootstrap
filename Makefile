IMAGE ?= y2khub/cljdroid
PLATFORM ?= linux/arm64
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: build
build:
	docker build --platform $(PLATFORM) -t $(IMAGE) .

.PHONY: test
test: build
	IMAGE=$(IMAGE) PLATFORM=$(PLATFORM) bash tests/build-command.sh
	IMAGE=$(IMAGE) PLATFORM=$(PLATFORM) bash tests/smoke.sh

.PHONY: publish
publish: test
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE) --push .
