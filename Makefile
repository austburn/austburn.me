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
			   --env "USE_S3=true" \
			   --env "USE_RDS=true" \
			   --link postgres:postgres \
			   --name austburn-prod austburn.app

update:
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --link postgres:postgres \
			   austburn.app sh -c "source /env/bin/activate && python migrations/posts.py"

test: py_lint js_lint

py_lint: img
	docker run --rm --interactive --tty \
				austburn.app sh -c "source /env/bin/activate && pep8 /application && pyflakes /application"

js_lint: img
	docker run --rm --interactive --tty austburn.app sh -c "npm run lint"

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres

deploy_test:
	ansible-playbook webservers.yml -e "git_revision=$(gr)" -e "app_env=test"

deploy_production:
	ansible-playbook webservers.yml -e "git_revision=$(gr)" -e "app_env=production"
