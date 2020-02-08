#!/bin/bash

dockercmd="docker-compose exec status"

cmd="${1}"
shift

usage(){
cat <<EOM
  Usage:
  
        $0 check|c [s]                  Check and optional store
        $0 msg|m "service" <message>    Send new Message
        $0 start | init                 Start service
        $0 stop | clean                 Stop service
        $0 reset                        Stop and start service

EOM
}

checkme(){
  if [ $# -eq 1 ]; then
    local add="--store"
  fi
  $dockercmd checkup $add
}

case $cmd in
  check|c)
   checkme $1
  ;;

  message|msg|m)
    service="${1}"
    shift
    $dockercmd checkup message --about="$service" "$*"
  ;;
  init|start)
    docker-compose up -d
  ;;
  clean|stop)
    docker-compose down -v
  ;;
  reset)
    docker-compose down -v
    docker-compose up -d
  ;;
  *)
    usage
  ;;
esac
