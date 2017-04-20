default: dev

img:
	docker build --tag austburn.app .

dev: img
	docker run --interactive --tty \
			   --restart always \
			   --publish 5050:5050 \
			   --name austburn-dev austburn.app sh -c "source /env/bin/activate && python runserver.py"

prod: img
	docker run --rm --interactive --tty \
			   --publish 5050:5050 \
			   --name austburn-prod austburn.app

test: py_lint js_lint

py_lint: img
	docker run --rm --interactive --tty \
				austburn.app sh -c "source /env/bin/activate && pep8 /application && pyflakes /application"

js_lint: img
	docker run --rm --interactive --tty austburn.app sh -c "npm run lint"

deploy_test:
	ansible-playbook webservers.yml -e "git_revision=$(gr)" -e "app_env=test"

deploy_production:
	ansible-playbook webservers.yml -e "git_revision=$(gr)" -e "app_env=production"

tf_plan:
	ansible-vault decrypt terraform.tfvars
	./terraform plan tf/
	ansible-vault encrypt terraform.tfvars

tf_apply:
	ansible-vault decrypt terraform.tfvars
	./terraform apply tf/
	ansible-vault encrypt terraform.tfvars
