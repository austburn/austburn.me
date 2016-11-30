default: dev

img:
	docker build --tag austburn.app .

dev: img
	docker run --interactive --tty \
			   --restart always \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-dev austburn.app sh -c "source /env/bin/activate && python migrations/posts.py && python runserver.py"

prod: img
	docker run --rm --interactive --tty \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-prod austburn.app

update:
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --link postgres:postgres \
			   austburn.app sh -c "source /env/bin/activate && python migrations/posts.py"

test: py_lint js_lint

py_lint:
	docker run --rm --interactive --tty \
				austburn.app sh -c "source /env/bin/activate && pep8 /application && pyflakes /application"

js_lint:
	docker run --rm --interactive --tty austburn.app sh -c "npm run lint"

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres

deploy_test:
	ansible-playbook webservers.yml --limit test -e "git_revision=$(gr)"

deploy_production:
	ansible-playbook webservers.yml --limit production -e "git_revision=$(gr)"
