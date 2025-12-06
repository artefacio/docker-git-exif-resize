FROM alpine:latest

ENV GIT_REPO=""
ENV GIT_BRANCH="master"
ENV GIT_ORIGIN="origin"
ENV COMMIT_USER="Username"
ENV COMMIT_EMAIL="git@example.com"
ENV WORKING_DIR="/git"
ENV FILES_TO_COMMIT="."
ENV SLEEP_INTERVAL="600"
ENV SUPPORTED_FILES="png,jpg,jpeg,gif"
ENV RESIZE_IMAGES="true"
ENV IMAGE_SIZE_MAX="800"

RUN apk update && \
        apk add git \
        openssh-client \
        exiftool \
        imagemagick-dev \
        imagemagick-jpeg \
        php${PHP_SHORT}-pecl-imagick 

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
