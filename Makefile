.PHONY: validate e2e test

validate:
	ruby scripts/validate.rb

e2e:
	ruby tests/e2e/minimal_controller_test.rb

test: validate e2e
