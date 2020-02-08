# Docker image for nsupdate


The DNS server can be configured to use the backend docker networkwith this snippet:


```
    networks:
      backend:
        ipv4_address: 192.168.255.2
```

In addition a database can also be added to the network with `192.168.255.4`.


## Linke:

- https://www.nsupdate.info/
- https://github.com/nsupdate-info/nsupdate.info
