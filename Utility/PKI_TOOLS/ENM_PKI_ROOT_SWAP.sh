#!/bin/bash
#
#
dbname="both"
threshold=1
states=""
#
usage() {
  echo "Usage: $0 active <active_serial_number> inactive <inactive_serial_number>"
  exit
}
#
while [ ! -z "$1" ]
do
  if [ "$1" == "active" ]; then
    shift
    if [ -z "$1" ]; then
      usage
    fi
    active="$1"
  fi
  if [ "$1" == "inactive" ]; then
    shift
    if [ -z "$1" ]; then
      usage
    fi
    inactive="$1"
  fi
  shift
done
#
if [ -z "$active" ] || [ -z "$inactive" ]; then
  usage
fi
#
if echo "$active" | egrep -v '[a-f0-9]' ; then
  echo "active serial number ($active) in wrong format: requires a-f0-9 only characters"
  usage
fi
#
if echo "$inactive" | egrep -v '[a-f0-9]' ; then
  echo "active serial number ($inactive) in wrong format: requires a-f0-9 only characters"
  usage
fi
#
#
echo "ARE YOU SURE YOU WANT TO SWAP:"
echo "  SN: $active  to INACTIVE"
echo "  SN: $inactive  to ACTIVE"
#
echo -n "Enter YES if OK: "
read r
#
if [ "$r" != "YES" ]; then
  echo "YES not entered, NO operation performed"
  exit
fi
#
# check on PG password
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
#
# 1: active
# 4: Inactive
#
# Swap: 4 <-> 1
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d pkicoredb <<_EOF_
update certificate set status_id=4 where serial_number='$active';
update certificate set status_id=1 where serial_number='$inactive';
_EOF_
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d pkimanagerdb <<_EOF_
update certificate set status_id=4 where serial_number='$active';
update certificate set status_id=1 where serial_number='$inactive';
_EOF_
#
echo "switch done Done:" $( date)
#
#
