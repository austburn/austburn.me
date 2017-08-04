default: dev

img:
	docker build --tag austburn .

dev: img
	docker run --interactive --tty \
			   --env "GIT_HASH=local" \
			   --restart always \
			   --publish 5050:5050 \
			   --name austburn-dev austburn sh -c "python runserver.py"

prod: img
	docker run --rm --interactive --tty \
			   --publish 5050:5050 \
			   --name austburn-prod austburn

test: py_lint js_lint

py_lint: img
	docker run --rm --interactive --tty \
				austburn sh -c "pep8 /application && pyflakes /application"

js_lint: img
	docker run --rm --interactive --tty austburn sh -c "npm run lint"

tf_plan:
	ansible-vault decrypt terraform.tfvars
	terraform plan tf || true
	ansible-vault encrypt terraform.tfvars

tf_apply:
	ansible-vault decrypt terraform.tfvars
	terraform apply tf || true
	ansible-vault encrypt terraform.tfvars
