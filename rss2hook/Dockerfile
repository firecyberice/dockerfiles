FROM golang:alpine AS build

RUN apk add -U git

WORKDIR /rss2hook-src
RUN git clone https://github.com/skx/rss2hook .

RUN CGO_ENABLED=1 go build -ldflags "-X main.version=$(git describe --tags)" -o /rss2hook
RUN CGO_ENABLED=0 go build -ldflags "-X main.version=$(git describe --tags)" -o /rss2hook-static

FROM alpine:latest
RUN apk add --no-cache ca-certificates
RUN adduser -s /sbin/nologin -H -u 1000 -D noroot \
    && mkdir -p /home/noroot/.rss2hook \
    && chown -R 1000:1000 /home/noroot/.rss2hook

COPY --chown=1000:1000 --from=build /rss2hook /usr/local/bin/
# COPY --chown=1000:1000 --from=build /rss2hook-static /usr/local/bin/

USER noroot
VOLUME /home/noroot/.rss2hook
ENTRYPOINT ["rss2hook"]
CMD ["-config", "/config.cfg"]
