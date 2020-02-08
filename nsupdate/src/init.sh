#!/bin/bash

chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www || true

set -e

echo "migrate / create database"
python3 manage.py makemigrations || true
python3 manage.py migrate || true

echo "collectstatic"
python3 manage.py collectstatic --noinput
