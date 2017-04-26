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

RUN cd /tmp && \
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip" && \
    unzip awscli-bundle.zip && \
    ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && \
    rm awscli-bundle.zip && rm -rf awscli-bundle

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

ENV PYTHONPATH /application
CMD . /env/bin/activate && python migrations/posts.py && \
    uwsgi app.ini
