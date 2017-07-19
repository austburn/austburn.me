# app
FROM python:2.7-alpine
RUN apk add --update --no-cache \
    bash \
    build-base \
    curl \
    cython \
    jansson \
    libffi-dev \
    linux-headers \
    nodejs \
    pcre-dev \
    postgresql-dev \
    py-psycopg2 \
    unzip

WORKDIR /application
COPY application/requirements /requirements
COPY application/package.json /tmp/package.json

RUN pip install virtualenv
RUN virtualenv /env
RUN . /env/bin/activate; pip install -r /requirements
RUN cd /tmp && npm install

COPY application /application
RUN mv /tmp/node_modules /application && npm run build && npm run minify_css

ENV PYTHONPATH /application
CMD . /env/bin/activate && uwsgi app.ini
