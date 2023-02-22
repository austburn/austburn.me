FROM alpine:3.17

RUN apk update && apk add --no-cache git hugo py3-pip gnupg terraform
RUN pip3 install --upgrade awscli
