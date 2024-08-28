#!/bin/bash
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
db="pkimanagerdb"
#
echo "Working on $db"
#
ca_name="NE_OAM_CA";
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db << _EOF_
BEGIN;
select ci.* from crlinfo ci join ca_crlinfo caci on caci.crlinfo_id = ci.id join caentity as cae on cae.id = caci.ca_id where cae.name='$ca_name';
COMMIT;
_EOF_
#
