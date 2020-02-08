FROM alpine:latest

ENV CHECKUP_URL=https://github.com/sourcegraph/checkup/releases/download/v0.2.0/checkup_linux_amd64.tar.gz \
    INIT_URL=https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64

WORKDIR /data
RUN apk add --no-cache curl ca-certificates \
    && curl -fsSL ${CHECKUP_URL} | tar -xz --strip-components 2 \
    && sed -i -e "s|s3.js|fs.js|g" statuspage/index.html \
    && mkdir -p bin/ root/ && mv checkup bin/checkup && mv statuspage root/ \
    && curl -fsSLo bin/dumb-init ${INIT_URL} \
    && chmod +x bin/dumb-init

RUN echo "create checkup.json" && echo -e "\
ewoKICAiY2hlY2tlcnMiOiBbCiAgICB7CiAgICAgICJ0eXBlIjogInRscyIsCiAgICAgICJlbmRw\
b2ludF9uYW1lIjogImdvb2dsZSIsCiAgICAgICJlbmRwb2ludF91cmwiOiAiZ29vZ2xlLmNvbTo0\
NDMiCiAgICB9CiAgXSwKICAic3RvcmFnZSI6CiAgICB7CiAgICAgICJwcm92aWRlciI6ICJmcyIs\
CiAgICAgICJkaXIiOiAic3RhdHVzcGFnZS9jaGVja3MiCiAgICB9Cn0K" \
| base64 -d|tee root/checkup.json 1>/dev/null

COPY config.js root/statuspage/js/config.js
COPY entrypoint.sh bin/docker-entrypoint.sh
RUN chmod +x bin/docker-entrypoint.sh

FROM golang:alpine
RUN apk add -U git gcc
RUN go get -v -d github.com/sourcegraph/checkup
WORKDIR /go/src/github.com/sourcegraph/checkup/cmd/checkup
RUN go get -v -d
ENV CGO_ENABLED=0
RUN go build -v -ldflags '-s' -o ../../checkup
RUN cd ../../ && pwd && ls -lAh

FROM busybox:latest
COPY --from=0 /etc/ssl /etc/ssl
COPY --from=0 /data/bin/ /usr/local/bin/
COPY --from=0 /data/root /
RUN mv /usr/local/bin/checkup /usr/local/bin/checkup-0.2.0
COPY --from=1 /go/src/github.com/sourcegraph/checkup/checkup /usr/local/bin/checkup

WORKDIR /
VOLUME /statuspage/checks
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["every","1m"]
