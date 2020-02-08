ARG ALPINE_VERSION=3.11
FROM alpine:${ALPINE_VERSION}

RUN apk add --update --no-cache \
    bind \
    bind-tools \
    bash \
    drill

ENV CACHE=/var/cache/bind \
    ZONEFILES=/etc/bind/zones

EXPOSE 53 53/udp
WORKDIR /etc/bind
VOLUME ["/var/cache/bind","/var/log/"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["-g"]

COPY fs/ /
