#!/usr/local/bin/dumb-init /bin/sh

httpd -f -v -p 80 -h /statuspage &

checkup --config /checkup.json --store --v

checkup --config /checkup.json $@
