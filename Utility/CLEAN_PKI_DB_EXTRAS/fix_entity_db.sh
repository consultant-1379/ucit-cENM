#!/bin/bash
#
nparallel=16
#
dbname="both"
threshold=1
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
if [ "$dbname" == "both" ]; then
  $0 pkicoredb $states $threshold
  $0 pkimanagerdb $states $threshold
  exit
fi
#
db=$dbname
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d pkicoredb <<_EOF_
do $$
declare
ids bigint[];
eid bigint;
begin
select into ids array_agg(entity_id) from entity_certificate where certificate_id not in ( select id from certificate);
IF ids IS NOT NULL
THEN
    FOREACH eid IN ARRAY ids
    LOOP
      UPDATE entity_info set status_id = 1 where status_id = 2 and id = eid;
    END LOOP;
END IF;
END $$;
_EOF_
#
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d pkimanagerdb <<_EOF_
do $$
declare
ids bigint[];
eid bigint;
begin
select into ids array_agg(entity_id) from entity_certificate where certificate_id not in ( select id from certificate);
IF ids IS NOT NULL
THEN
    FOREACH eid IN ARRAY ids
    LOOP
      UPDATE entity set status_id = 1 where status_id = 2 and id = eid;
    END LOOP;
END IF;
END $$;
_EOF_
#
