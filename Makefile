all: push-down-test

.PHONY: push-down-test
push-down-test:
	@cd ./push-down-test && bash ./run-tests.sh full-test

.PHONY: no-push-down
no-push-down:
	@cd ./push-down-test && bash ./run-tests.sh no-push-down

.PHONY: push-down-without-vec
push-down-without-vec:
	@cd ./push-down-test && bash ./run-tests.sh push-down-without-vec

.PHONY: push-down-with-vec
push-down-with-vec:
	@cd ./push-down-test && bash ./run-tests.sh push-down-with-vec

.PHONY: clean
clean:
	@cd ./push-down-test && bash ./run-tests.sh clean
