#!/bin/bash
set -e

for f in /docker-entrypoint-init.d/*; do
  case "$f" in
    *.sh) echo "$0: running $f"; . "$f" ;;
    *)    echo "$0: ignoring $f" ;;
  esac
  echo
done

echo "prepare apache"
# Apache gets grumpy about PID files pre-existing
rm -f "${APACHE_PID_FILE}"
mkdir -p "${APACHE_LOG_DIR}" "${APACHE_LOCK_DIR}"

if [[ "$1" == "development" ]]; then
  echo "start python3 development mode"
  exec python3 manage.py runserver 0.0.0.0:80
else
  echo "start apache"
  exec apache2 -DFOREGROUND
fi
