.PHONY: push-down-test

all: push-down-test

push-down-test:
	cd push-down-test && bash run-tests.sh