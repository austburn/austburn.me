# app
FROM alpine:3.4
RUN apk add --update \
    ca-certificates gcc linux-headers openssl-dev \
    build-base python python-dev py-pip py-psycopg2 cython \
    libffi-dev pcre-dev postgresql-dev jansson \
    nodejs

WORKDIR /application
COPY application/requirements /requirements
COPY application/package.json /tmp/package.json

RUN pip install --upgrade pip virtualenv
RUN virtualenv /env
RUN . /env/bin/activate; pip install -r /requirements
RUN cd /tmp && npm install

COPY application /application
RUN mv /tmp/node_modules /application && npm run build && npm run minify_css
ENV PYTHONPATH /application

CMD . /env/bin/activate && python migrations/posts.py && \
    uwsgi app.ini
