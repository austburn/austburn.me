default: dev

base-img:
	docker build --tag austburn.base --file ./docker/base.docker docker

dev-img: base-img
	docker build --tag austburn.dev --file ./docker/dev.docker docker

prod-img: base-img
	docker build --tag austburn.prod --file ./docker/prod.docker docker

dev: dev-img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --volume $(shell pwd)/migrations:/migrations \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-dev austburn.dev

prod: prod-img
	docker run --rm --interactive --tty \
			   --volume $(shell pwd)/application:/application \
			   --volume $(shell pwd)/migrations:/migrations \
			   --publish 5050:5050 \
			   --link postgres:postgres \
			   --name austburn-prod austburn.prod

db:
	docker run --detach --env POSTGRES_USER=local --env POSTGRES_PASSWORD=local --name postgres postgres
