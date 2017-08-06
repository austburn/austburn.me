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
    unzip

COPY application/requirements /requirements
COPY application/package.json /tmp/package.json

RUN pip install -r /requirements
RUN cd /tmp && npm install

COPY application /application
WORKDIR /application
RUN mv /tmp/node_modules /application && npm run build && npm run minify_css

ENV PYTHONPATH /application
CMD uwsgi app.ini
