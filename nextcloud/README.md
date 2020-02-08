# Docker image for nextcloud with restic


Please add a tmpfs to the docker-compose.yaml for the restic cache
```
    tmpfs:
      - /root/.cache/restic
```
