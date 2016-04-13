default: dev

img:
	docker build --tag austburn.app --file ./docker/app.docker docker

dev: img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-dev austburn.app bash -c "source /env/bin/activate && python migrations/posts.py && python runserver.py"

prod: img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-prod austburn.app

update:
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --link postgres:postgres \
			   austburn.app bash -c "source /env/bin/activate && python migrations/posts.py"

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres
