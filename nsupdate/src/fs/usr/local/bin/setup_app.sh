#!/bin/bash

#SERVICE=${1:-all}

function cfg_setup(){
  echo "pip3 install"
  pip3 install -r requirements.txt
}

function cfg_db(){
  echo "migrate / create database"
  python3 manage.py migrate
}

function cfg_static(){
  echo "collectstatic"
  python3 manage.py collectstatic --noinput
}

function cfg_admin(){
  echo "create admin user"
  python3 manage.py createsuperuser --username=admin --email=admin@example.com
}

if [[ $# -eq 1 ]]; then
  case ${1} in
    setup)
      cfg_setup
    ;;
    db)
      cfg_db
    ;;
    static)
      cfg_static
    ;;
    admin)
      cfg_admin
    ;;

    all)
      cfg_setup
      cfg_db
      cfg_static
      cfg_admin
    ;;
    *)
cat << EOM
  usage:
    $0 <all|setup|db|static|admin>

    setup    install requirements.txt
    db       migrate database
    static   collect static files
    admin    create admin user
    all      do all jobs: (setup; db; static; admin)
EOM
    ;;
  esac
fi
