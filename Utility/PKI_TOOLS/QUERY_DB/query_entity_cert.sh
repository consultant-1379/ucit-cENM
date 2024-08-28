#!/bin/bash
#
th=$(echo $1 | bc -l)
#
if [ -z "$th" ]; then
  th=1
fi
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
SELECT DISTINCT count(*), e.name FROM certificate c join entity_certificate ec on ec.certificate_id = c.id join entity as e on ec.entity_id = e.id group by e.name HAVING COUNT(c.id) > $th order by count desc;
_EOF_
#
