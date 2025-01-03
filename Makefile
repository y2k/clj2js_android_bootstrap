.PHONY: build
build:
	docker build --platform linux/arm64 -t y2khub/cljdroid .

.PHONY: deploy
deploy: build
	docker push y2khub/cljdroid

.PHONY: buildx
buildx:
	docker buildx build --platform linux/amd64,linux/arm64 -t y2khub/cljdroid . --push
