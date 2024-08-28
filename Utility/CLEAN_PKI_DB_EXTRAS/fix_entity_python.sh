#!/bin/bash
#
# check on PG password
#
function print_n() {
  if [ "$1" == 0 ]; then
     echo "NONE"
  else
     echo $1
  fi
}
#
if [ -z ${PGPASSWORD} ]; then
  if [ -r /ericsson/enm/pg_utils/lib/pg_password_library.sh ]; then
    source /opt/ericsson/pgsql/etc/postgres01.config
    source /ericsson/enm/pg_utils/lib/pg_syslog_library.sh
    source /ericsson/enm/pg_utils/lib/pg_password_library.sh
    export_password > /dev/null 2>&1
  else
    read -s -p "Enter postgres password:" pass
    export PGPASSWORD="$pass"
    echo ""
  fi
fi
#
./fix_entity.py
#
