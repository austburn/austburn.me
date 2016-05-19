default: dev

img:
	docker build --tag austburn.app --file docker/app.docker .

dev: img
	docker run --rm --interactive --tty \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-dev austburn.app bash -c "source /env/bin/activate && python migrations/posts.py && python runserver.py"

prod: img
	docker run --rm --interactive --tty \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-prod austburn.app

update:
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --link postgres:postgres \
			   austburn.app bash -c "source /env/bin/activate && python migrations/posts.py"

test:
	docker run --rm --interactive --tty \
				austburn.app bash -c "source /env/bin/activate && pep8 /application && pyflakes /application"

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres
