#!/bin/bash

#-----------#
# VARIABLES #
#-----------#
user_group=100:101

#-----------#
# FUNCTIONS #
#-----------#
function linking(){
  mkdir -p "${CACHE}"
  chmod a+w "${CACHE}"
  if [[ ! -f "${CACHE}/${lower}" ]]; then
    echo "\$INCLUDE ${ZONEFILES}/${lower}" > "${CACHE}/${lower}"
  fi
  chown -R "${user_group}" "${CACHE}"
}

#------#
# MAIN #
#------#
old=$(pwd)
mkdir -p ${ZONEFILES}
cd ${ZONEFILES}
if [[ "$(ls -A .)" ]]; then
  for zone in *; do
    lower=$(echo "${zone}" |tr '[:upper:]' '[:lower:]')
    echo "create link for ${zone}"
    linking
  done
fi
cd "${old}"

echo -e "\nstarting bind $(named -v)"
exec named "${@}"
