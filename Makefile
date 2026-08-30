IMAGE ?= y2khub/cljdroid
PLATFORM ?= linux/arm64
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: build
build:
	docker build --platform $(PLATFORM) -t $(IMAGE) .

.PHONY: test
test: build
	docker run --rm --platform $(PLATFORM) --entrypoint ./gradlew $(IMAGE) assembleDebug --no-daemon --no-watch-fs -q

.PHONY: publish
publish: test
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE) --push .
