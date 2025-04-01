all: push-down-test

.PHONY: push-down-test
push-down-test: clean
	@cd ./push-down-test && bash ./run-tests.sh full-test

.PHONY: no-push-down
no-push-down:
	@cd ./push-down-test && bash ./run-tests.sh no-push-down

.PHONY: push-down-with-vec
with-push-down:
	@cd ./push-down-test && bash ./run-tests.sh with-push-down

.PHONY: clean
clean:
	@cd ./push-down-test && bash ./run-tests.sh clean

