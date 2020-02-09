# Docker image for nextcloud with restic

Please add a tmpfs to the docker-compose.yaml for the restic cache

```
    tmpfs:
      - /root/.cache/restic
      - /var/www/.cache/restic
```


### Variables needed for restic:

These can also be mounted to `/restic.env` inside the container

```
RESTIC_REPOSITORY
RESTIC_PASSWORD
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```


### Usage

```
Usage:

nc-br [flag] command

backup                          Make backup
restore <RESTIC_SNAPSHOT>       Restore specified snapshot
snapshots                       List snapshots
stats                           Show repository statistics
cleanup                         Cleanup old backups
restic                          Wrapper around restic to set repo and password

Available flags for backup and restore
        -a      installed apps
        -c      config
        -d      data
        -s      sqldatabase
        -h      html folder without config  and data
```
