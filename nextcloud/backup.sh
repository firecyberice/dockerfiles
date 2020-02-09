#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/

set -e -o pipefail
#set -u
#IFS=$'\t\n'

if [[ ${DEBUG} == "true" ]]; then
  set -x
fi

###############################
trap_clean(){
  unset RESTIC_REPOSITORY
  unset RESTIC_PASSWORD
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
}
trap trap_clean EXIT

timestamp=$(date --utc +%Y%m%d-%H%M%z)
###############################
BOLD='\e[1m'
NORMAL='\e[0m'
NO_COLOR='\033[0m'
#MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_BLUE='\033[1;34m'
#LIGHT_RED='\033[1;31m'
#LIGHT_PURPLE='\033[1;35m'

info() { ## Prints colorful info messages on runtime
    printf "${CYAN}${BOLD}%s${NORMAL}${NO_COLOR}\n" "$@"
}

testvars(){
  # shellcheck disable=SC2048
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

###############################
# shellcheck disable=SC2016,SC2034
occ='su -l -g www-data -s /bin/bash -c "${OCC_CMD}" www-data'

backupapps(){
  local filename="${1:-/tmp/installed_apps_at_${timestamp}.json}"
  info "Backup list of installed and enabled apps"
  # shellcheck disable=SC2034
  OCC_CMD="/var/www/html/occ app:list --no-interaction --output=json_pretty"
#  eval "$occ" > "${filename}"
  ${OCC_CMD} > "${filename}"
}

restoreapps(){
  local applist="${1:-/tmp/installed_apps_at_${timestamp}.json}"
  [[ -f ${applist} ]] || return
  info "Restore list of installed and enabled apps"
#/var/www/html/occ maintenance:mode --on
set +e
  info "Disable not needed apps"
  OCC_CMD="/var/www/html/occ app:disable"
  # shellcheck disable=SC2086
  jq -r '.disabled|keys|.[]' <"${applist}" | xargs -n 1 -I I ${OCC_CMD} I 2>/dev/null

  info "Install needed apps"
  OCC_CMD="/var/www/html/occ app:install"
  # shellcheck disable=SC2086
  jq -r '.enabled|keys|.[]' <"${applist}" | xargs -n 1 -I I ${OCC_CMD} I 2>/dev/null

  info "Enable needed apps"
  OCC_CMD="/var/www/html/occ app:enable"
  # shellcheck disable=SC2086
  jq -r '.enabled|keys|.[]' <"${applist}" | xargs -n 1 -I I ${OCC_CMD} I 2>/dev/null
set -e
  info "Upgrade all apps"
  # shellcheck disable=SC2034
  OCC_CMD="/var/www/html/occ app:update --all"
  ${OCC_CMD}
#/var/www/html/occ maintenance:mode --off
}

###############################
build_excludes(){
  local EXCLUDES=${DEFAULT_EXCLUDES}
  if [[ $# -ne 0 ]]; then
    # shellcheck disable=SC2048
    for i in $*; do
      EXCLUDES="$EXCLUDES --exclude $i"
    done
  fi
  echo "${EXCLUDES}"
}

read_config(){
  if [[ -f ${CONFIG_FILE} ]]; then
    CONF_MYSQL_HOST=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbhost'];")
    CONF_MYSQL_NAME=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbname'];")
    CONF_MYSQL_USER=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbuser'];")
    CONF_MYSQL_PASS=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['dbpassword'];")
    DOMAIN="--host $(php -r "include '${CONFIG_FILE}'; print \$CONFIG['trusted_domains'][0];")"
    DATADIRECTORY=$(php -r "include '${CONFIG_FILE}'; print \$CONFIG['datadirectory'];")
    [[ -n ${DATADIRECTORY} ]] && {
      DATADIR=$(basename "${DATADIRECTORY}")
      DATAWORKDIR=$(dirname "${DATADIRECTORY}")
    }
  fi
}

check_mysqlvars(){
  if [[ $(testvars CONF_MYSQL_HOST CONF_MYSQL_NAME CONF_MYSQL_USER CONF_MYSQL_PASS) != true ]]; then
    info "Database settings not found. Exiting"
    exit 1
  fi
}

wait-for-mysql(){
  while ! (mysqladmin ping --host="${CONF_MYSQL_HOST}" --user="${CONF_MYSQL_USER}" --password="${CONF_MYSQL_PASS} "> /dev/null 2>&1)
    do
       sleep 3
       echo "waiting for mysql ..."
    done
}

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
      restic forget --dry-run --path /databasedump.sql --keep-last "${1}"
      restic forget --dry-run --path "${WORKDIR}/${DATADIR:-data}" --path "${WORKDIR}/config" --keep-last "${1}"
    else
      restic forget --dry-run \
        --keep-hourly 24 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --keep-yearly 2

:<<CLEANUP
      restic forget --dry-run \
        --path "${WORKDIR}/config" \
        --path "${WORKDIR}/${DATADIR:-data}" \
        --keep-hourly 24 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --keep-yearly 2
 
      restic forget --dry-run \
        --path "/databasedump.sql" \
        --keep-hourly 24 \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 12 \
        --keep-yearly 2
CLEANUP
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
    VOLUMES=""
    [[ $BACKUP_CONFIG == true ]] && VOLUMES="${VOLUMES}config "
    [[ $BACKUP_DATA == true ]] && VOLUMES="${VOLUMES}${DATADIR:-data} "
    [[ $BACKUP_CONFIG == true || $BACKUP_DATA == true ]] && {
      info "Backup ${VOLUMES}"
      [[ $BACKUP_CONFIG == true ]] && backupapps "${WORKDIR}/config/installed_apps.json"
      cd "${WORKDIR}"
      # shellcheck disable=SC2086
      restic backup ${RESTIC_OPTS} --exclude restic.env ${VOLUMES}
    }
    [[ $BACKUP_SQL == true ]] && {
      read_config
      check_mysqlvars
      info "Create database dump"
      # shellcheck disable=SC2086
      mysqldump -h "${CONF_MYSQL_HOST}" -u "${CONF_MYSQL_USER}" -p"${CONF_MYSQL_PASS}" ${MYSQL_DUMP_OPTIONS} "${CONF_MYSQL_NAME}" |restic backup ${RESTIC_OPTS} --stdin --stdin-filename databasedump.sql
    }
    [[ $BACKUP_HTML == true ]] && {
      cd "${WORKDIR}"
      info "Backup html without data and config"
      # shellcheck disable=SC2086,SC2046
      restic backup ${RESTIC_OPTS} $(build_excludes "config ${DATADIR:-data}") "${WORKDIR}"
    }
}

restore() { ## Restores DSpace-CRIS from given ${RESTIC_SNAPSHOT}
    # shellcheck disable=SC2236
    if [[ ! -n ${RESTIC_SNAPSHOT} ]]; then
      info "No RESTIC_SNAPSHOT given to restore. Exiting"
      exit 0
    fi
    info "RESTIC_SNAPSHOT to restore is: ${RESTIC_SNAPSHOT}"
    INCLUDES=""
    [[ $BACKUP_CONFIG == true ]] && INCLUDES="${INCLUDES}--include config --path ${WORKDIR}/config "
    [[ $BACKUP_DATA == true ]] && INCLUDES="${INCLUDES}--include ${DATADIR:-data} --path ${WORKDIR}/${DATADIR:-data} "
    [[ $BACKUP_CONFIG == true || $BACKUP_DATA == true ]] && {
      info "Restoring with ${INCLUDES}"
      # shellcheck disable=SC2086
       restic restore --target "${WORKDIR}" ${INCLUDES} "${RESTIC_SNAPSHOT}"
    }
#    wait-for-database
    [[ $BACKUP_SQL == true ]] && {
      read_config
      check_mysqlvars
      wait-for-mysql
      info "Restoring database"
      restic dump --path /databasedump.sql "${RESTIC_SNAPSHOT}" /databasedump.sql |mysql -h "${CONF_MYSQL_HOST}" -u "${CONF_MYSQL_USER}" -p"${CONF_MYSQL_PASS}" "${CONF_MYSQL_NAME}"
    }
    [[ $BACKUP_APPS == true ]] && {
      info "Upgrade nextcloud"
      # shellcheck disable=SC2034
      OCC_CMD="/var/www/html/occ upgrade"
      ${OCC_CMD}
      info "Upgrade all apps"
      # shellcheck disable=SC2034
      OCC_CMD="/var/www/html/occ app:update --all"
      ${OCC_CMD}
      restoreapps "${WORKDIR}/config/installed_apps.json"
    }
}

usage(){
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "backup" "Make backup"
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "restore <RESTIC_SNAPSHOT>" "Restore specified snapshot"
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "snapshots" "List snapshots"
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "stats" "Show repository statistics"
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "cleanup" "Cleanup old backups"
    printf "${LIGHT_BLUE}${BOLD}%-30s${NORMAL}${NO_COLOR}\t%s\n" "restic" "Wrapper around restic to set repo and password"

    printf "\n%10s\n" "Available flags for backup and restore"

    printf "${CYAN}${BOLD}%10s${NORMAL}${NO_COLOR}\t%s\n" "-a" "installed apps"
    printf "${CYAN}${BOLD}%10s${NORMAL}${NO_COLOR}\t%s\n" "-c" "config"
    printf "${CYAN}${BOLD}%10s${NORMAL}${NO_COLOR}\t%s\n" "-d" "data"
    printf "${CYAN}${BOLD}%10s${NORMAL}${NO_COLOR}\t%s\n" "-s" "sqldatabase"
    printf "${CYAN}${BOLD}%10s${NORMAL}${NO_COLOR}\t%s\n" "-h" "html folder without config  and data"

}

###############################
DEFAULT_EXCLUDES="--exclude *~ --exclude .cache/"
WORKDIR=/var/www/html
CONFIG_FILE=${WORKDIR}/config/config.php

#RESTIC_CREDENTIALS=${WORKDIR}/config/restic.env
:${RESTIC_CREDENTIALS:-/restic.env}

DOMAIN="--host $(php -r "include '${CONFIG_FILE}'; print \$CONFIG['trusted_domains'][0];")"

RESTIC_OPTS="${DOMAIN:-} --tag NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION} --tag TYPE=docker-container ${TAGS:-}"
MYSQL_DUMP_OPTIONS="--dump-date --single-transaction --quick --routines --add-drop-database --add-drop-table --add-drop-trigger"

###############################

if [[ -f ${RESTIC_CREDENTIALS} ]]; then
# shellcheck disable=SC1090
  source ${RESTIC_CREDENTIALS}
fi

# backup to restic only if vars are set correctly otherwise write debug message
if [[ $(testvars RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY) != true ]]; then
  info "Missing parameters for restic. Exiting"
  exit 1
fi

#:${RESTIC_REPOSITORY}
#:${RESTIC_PASSWORD}
#:${AWS_ACCESS_KEY_ID}
#:${AWS_SECRET_ACCESS_KEY}

export RESTIC_REPOSITORY
export RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

BACKUP_SQL=false
BACKUP_CONFIG=false
BACKUP_DATA=false
BACKUP_HTML=false
BACKUP_APPS=false

# read the option and store in the variable, $option
while getopts "ascdh" option; do
  case ${option} in
    s ) #For option sqldump
      BACKUP_SQL=true
    ;;
    c ) #For option config
      BACKUP_CONFIG=true
    ;;
    d ) #For option data
      BACKUP_DATA=true
    ;;
    h ) #For option html
      BACKUP_HTML=true
    ;;
    a ) #For option apps
      BACKUP_APPS=true
    ;;
    \? ) #For invalid option
      echo "You have to use: [-c] or [-d] or [-h]"
      exit 1
    ;;
  esac
done
shift $((OPTIND-1))
if [[ $BACKUP_SQL == false && $BACKUP_CONFIG == false && $BACKUP_DATA == false && $BACKUP_HTML == false && $BACKUP_APPS == false ]]; then
  BACKUP_SQL=true
  BACKUP_CONFIG=true
  BACKUP_DATA=true
fi
if [[ $BACKUP_HTML == true ]]; then
  BACKUP_SQL=false
  BACKUP_CONFIG=false
  BACKUP_DATA=false
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
    # shellcheck disable=SC2086
    g_f_s ${1}
  ;;
  restic)
# shellcheck disable=SC2068
    restic ${@}
#    restic_wrapper ${@}
  ;;
  install)
    OCC_CMD="/var/www/html/occ maintenance:install --no-interaction --admin-user ${ADMIN_USER} --admin-pass ${ADMIN_PASS} --admin-email ${ADMIN_MAIL} --database ${MYSQL_TYPE} --database-host ${MYSQL_HOST} --database-port ${MYSQL_PORT} --database-name ${MYSQL_DATABASE} --database-user ${MYSQL_USER} --database-pass ${MYSQL_PASSWORD}"
    ${OCC_CMD}
#    eval ${occ}
  ;;
  *)
    usage
  ;;
esac

exit 0
