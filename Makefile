.PHONY: push-down-test

all: push-down-test

push-down-test:
	cd push-down-test && sh run-tests.sh