.PHONY: build
build:
# docker build --platform linux/arm64 -t y2khub/cljdroid .
	docker buildx build --platform linux/arm64 -t y2khub/cljdroid . --load

.PHONY: deploy
deploy: build
	docker push y2khub/cljdroid
