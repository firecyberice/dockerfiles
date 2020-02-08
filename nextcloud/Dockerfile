ARG NEXTCLOUD_IMAGE_TAG=17.0-apache
ARG MARIADB_IMAGE_TAG=10.3

FROM nextcloud:${NEXTCLOUD_IMAGE_TAG} AS base
FROM mariadb:${MARIADB_IMAGE_TAG} AS mariadb

FROM alpine:latest AS restic
WORKDIR /data
RUN apk add --no-cache curl bzip2

ARG RESTIC_VERSION=0.9.6
ENV RESTIC_URL=https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2
RUN curl -fsLo restic.bz2 ${RESTIC_URL} && bunzip2 restic.bz2

COPY backup.sh /data/nc-br
RUN chmod +x nc-br restic

FROM base AS release
COPY --from=restic /data/ /usr/local/bin/
COPY --from=mariadb /usr/bin/mysqldump /usr/bin/mysqldump
#RUN apt update && apt install -y --no-install--recommends mariadb-client-10.3 && rm -rf /var/lib/apt/lists/*
