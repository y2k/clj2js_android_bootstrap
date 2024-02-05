deploy: build
	docker push y2khub/cljdroid

build:
	docker build -t y2khub/cljdroid .

.PHONY: deploy build
