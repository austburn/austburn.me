default: dev

img:
	docker build --tag austburn.app --file ./docker/app.docker docker

dev: img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --volume $(shell pwd)/migrations:/migrations \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-dev austburn.app

prod: img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --volume $(shell pwd)/migrations:/migrations \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-prod austburn.app /env/bin/activate && python /migrations/posts.py && uwsgi --json uwsgi.json

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres
