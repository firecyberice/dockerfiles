#!/usr/bin/env bash

if [[ ${DEBUG} == "true" ]]; then
  set -e -x -o pipefail
else
  set -e -o pipefail
fi

BOLD='\e[1m'
NORMAL='\e[0m'
MAGENTA='\033[35m'
NO_COLOR='\033[0m'

info() { ## Prints colorful info messages on runtime
    printf "${MAGENTA}${BOLD}%s${NORMAL}${NO_COLOR}\n" "$@"
}

testvars(){
  for i in $*; do
    if [[ -z ${!i} ]]; then
#      echo "$i : ${!i}" >&2
      echo false
      return 1
    fi
  done
  echo true
  return 0
}

build_excludes(){
  local EXCLUDES=${DEFAULT_EXCLUDES}
  if [[ $# -ne 0 ]]; then
    for i in $@; do
      EXCLUDES="$EXCLUDES --exclude $i"
    done
  fi
  echo ${EXCLUDES}
}


DEFAULT_EXCLUDES="--exclude *~ --exclude .cache/"
WORKDIR=/var/www/html
VOLUMES="config data"
RESTIC_CREDENTIALS=${WORKDIR}/config/restic.env

CONFIG_FILE=${WORKDIR}/config/config.php

MYSQL_HOST=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbhost'];")
MYSQL_NAME=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbname'];")
MYSQL_USER=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbuser'];")
MYSQL_PASS=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbpassword'];")
DOMAIN="--host $(php -r "include '${CONFIG_FILE}'; print \$CONFIG['trusted_domains'][0];")"

RESTIC_OPTS="${DOMAIN} --tag NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION} --tag TYPE=docker-container"
MYSQL_DUMP_OPTIONS=""


snapshots() { ## Show restic snapshots
    info "Available Snapshots"
    restic snapshots
}

stats() { ## Show restic statistics
    info "Repo statistics"
    restic stats
    info "Repo raw statistics"
    restic stats --mode raw-data
}

g_f_s(){
    info "Restic cleanup"
    if [[ $# -eq 1 ]]; then
      restic forget --dry-run --path /databasedump.sql --keep-last $1
      restic forget --dry-run --path ${WORKDIR}/data ${WORKDIR}/config --keep-last $1
    else
      restic forget --dry-run \
        --keep-hourly 24 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --keep-yearly 2
    fi
#      --keep-last n            keep the last n snapshots
#      --keep-within duration   keep snapshots that are newer than duration (eg. 1y5m7d2h) relative to the latest snapshot
#      --path path              only consider snapshots which include this (absolute) path (can be specified multiple times)
#      --host host              only consider snapshots with the given host
#      --keep-tag taglist       keep snapshots with this taglist (can be specified multiple times) (default [])
#      --tag taglist            only consider snapshots which include this taglist in the format `tag[,tag,...]` (can be specified multiple times) (default [])
}

backup() { ## Backups nectcloud (database and volumes/directories given in $VOLUMES) with restic to ${RESTIC_REPOSITORY}
    info "Create restic repo if not exists: $(restic init 1>/dev/null || true)"
    info "Create database dump"
    mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DUMP_OPTIONS} ${MYSQL_NAME} |restic backup ${RESTIC_OPTS} --stdin --stdin-filename databasedump.sql
    info "Backup ${VOLUMES}"
    restic backup ${RESTIC_OPTS} --exclude restic.env ${VOLUMES}
#    info "Backup html without data and config"
#    restic backup ${RESTIC_OPTS} $(build_excludes ${VOLUMES}) .
}

restore() { ## Restores DSpace-CRIS from given ${RESTIC_SNAPSHOT}
    if [[ ! -n ${RESTIC_SNAPSHOT} ]]; then
      info "No RESTIC_SNAPSHOT given to restore. Exiting"
      exit 0
    fi
    info "RESTIC_SNAPSHOT to restore is: ${RESTIC_SNAPSHOT}"
    info "Restoring data and config"
    restic restore --target "${WORKDIR}" --path data --path config "${RESTIC_SNAPSHOT}"

    info "Restoring database"
#    wait-for-database
    restic dump --path /databasedump.sql "${RESTIC_SNAPSHOT}" /databasedump.sql |mysql -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_NAME}
}

usage(){
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "backup" "Make backup"
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "restore <RESTIC_SNAPSHOT>" "Restore specified snapshot"
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "snapshots" "List snapshots"
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "stats" "Show repository statistics"
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "cleanup" "Cleanup old backups"
      printf "${MAGENTA}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "restic" "Wrapper around restic to set repo and password"
}

if [[ -f ${RESTIC_CREDENTIALS} ]]; then
  source ${RESTIC_CREDENTIALS}
fi

# backup to restic only if vars are set correctly otherwise write debug message
if [[ $(testvars RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY) != true ]]; then
  info "Missing parameters for restic. Exiting"
  exit 1
fi

export RESTIC_REPOSITORY
export RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

cd ${WORKDIR}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

CMD=${1}
shift

case $CMD in
  backup)
    backup
  ;;
  restore)
    RESTIC_SNAPSHOT=${1}
    restore
  ;;
  snapshots)
    snapshots
  ;;
  stats)
    stats
  ;;
  cleanup)
    g_f_s ${1}
  ;;
  restic)
    restic ${@}
#    restic_wrapper ${@}
  ;;
  *)
    usage
  ;;
esac


exit 0


:<<EOM
wait-for-database() { ## Waits for Postgres to come up
    until psql -h "$POSTGRES_DB_HOST" -U "postgres" -c '\l'; do
        >&2 info "Postgres is unavailable - sleeping"
        sleep 1
    done
    >&2 info "Postgres is up - executing command"
}

check_if_db_exists(){
  if [[  $(testvars POSTGRES_DB_HOST POSTGRES_DB_PORT) == false ]]; then
    info "Please create a postgres container within the same docker network."
    exit 1
  fi

  if [ -n "$POSTGRES_ADMIN_PASSWORD" ]; then
    export PGPASSWORD=$POSTGRES_ADMIN_PASSWORD
  fi

  psql -h "$POSTGRES_DB_HOST" -p "$POSTGRES_DB_PORT" -d postgres -U "$POSTGRES_ADMIN_USER" -lqt | cut -d \| -f 1 | grep -qw "${POSTGRES_DB}"
  ret_=$?
  # ret_ is '1' if db does not exist otherwise '0'
  echo $ret_
  return $ret_
}
EOM