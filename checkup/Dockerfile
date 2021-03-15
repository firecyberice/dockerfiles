FROM golang:1.15-alpine as builder
RUN apk --no-cache add git make

ENV CGO_ENABLED=0
WORKDIR /app

RUN git clone https://github.com/sourcegraph/checkup .
RUN make build

FROM alpine:latest
WORKDIR /app

COPY --from=builder /app/builds/checkup /usr/local/bin/checkup
COPY --from=builder /app/statuspage/ /app/statuspage

COPY checkup.json /app/checkup.json
COPY config.js /app/statuspage/config.js

USER nobody
EXPOSE 3000
VOLUME /app/checks

ENTRYPOINT ["checkup"]
CMD ["serve"]
