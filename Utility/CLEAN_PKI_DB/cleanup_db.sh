#!/bin/bash
#
nparallel=20
#
sql_create="create_function_delete_certificates.sql"
sql_id="delete_certificate_id.sql"
#
dbname="both"
threshold=1
states=""
#
while [ ! -z "$1" ]
do
  if echo "$1" | egrep -q "expired|revoked|inactive" ; then
    states="$1"
    shift
  fi

  if echo "$1" | egrep -q "pkicoredb|pkimanagerdb|both" ; then
    dbname="$1"
    shift
  fi

  if echo "$1" | egrep -q "[0-9]" ; then
    threshold="$1"
    shift
  fi
done

#
# states to remove:
# 4: Inactive
# 3: Expired
# 2: Revoked
#
if [ -z "$states" ]; then
  states_to_remove="2,3,4"
else
  states_to_remove=""
  if echo "$states" | grep -q "expired" ; then
    id=2
    if [ -z "$states_to_remove" ]; then
      states_to_remove="$id"
    else
      states_to_remove="$states_to_remove,$id"
    fi
  fi
  if echo "$states" | grep -q "revoked" ; then
    id=3
    if [ -z "$states_to_remove" ]; then
      states_to_remove="$id"
    else
      states_to_remove="$states_to_remove,$id"
    fi
  fi
  if echo "$states" | grep -q "inactive" ; then
    id=4
    if [ -z "$states_to_remove" ]; then
      states_to_remove="$id"
    else
      states_to_remove="$states_to_remove,$id"
    fi
  fi
#
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
if [ "$dbname" == "both" ]; then
  $0 pkicoredb $states $threshold
  $0 pkimanagerdb $states $threshold
  exit
fi
#
db=$dbname
#
echo "Working on db: $db on certificates with states=$states_to_remove using threshold=$threshold"
#
#exit
#
# Work on pkimanagerdb
#
echo "Delte old functions if any"
#
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g' | sed 's/^ERROR: \(function .*\) does not exists/NOTE: \1/') <<_EOF_
DROP FUNCTION delete_certificates(aa integer, VARIADIC states integer[]);
_EOF_
#
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g' | sed 's/^ERROR: \(function .*\) does not exists/NOTE: \1/') <<_EOF_
DROP FUNCTION delete_certificates(ent_id integer, threshold integer, VARIADIC states integer[]);
DROP FUNCTION table_exists(table_name varchar);
DROP FUNCTION delete_cert_id(table_name varchar);
DROP FUNCTION delete_cert_id(cert_id bigint, states integer[]);
_EOF_
#
#
entity_id=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT DISTINCT entity_id from entity_certificate; 
_EOF_
)

/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db -f $sql_create

len=$(echo "$entity_id" | wc -l)
cnt=$len
#
echo "$len ID to be processed"
#
echo "Start:" $( date )
for id in $entity_id
do
  echo "Processing ID:$id, ($cnt remaining)"
  nproc=$(ps -elaf | grep "$sql_id" | grep $db | grep -v grep | wc -l)
  echo "nproc=$nproc"
  while [ $nproc -ge $nparallel ]
  do
    sleep 2
    nproc=$(ps -elaf | grep "$sql_id" | grep $db | grep -v grep | wc -l)
    echo "nproc=$nproc"
  done
  ( /opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db -f $sql_id -v ent_id=$id -v states="$states_to_remove" -v threshold="$threshold" ; echo "ID:$id done") &
  if [ $cnt -gt 0 ]; then
    cnt=$(( cnt - 1 ))
  else
    echo "END ID"
  fi
done
#
echo "Waiting for latest jobs to complete"
#
nproc=$(ps -elaf | grep "$sql_id" | grep $db | grep -v grep | wc -l)
while [ $nproc -gt 0 ]
do
  nproc=$(ps -elaf | grep "$sql_id" | grep $db | grep -v grep | wc -l)
  sleep 2
done
echo "End phase 1:" $( date)
#
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
DROP FUNCTION delete_certificates(ent_id integer, threshold integer, VARIADIC states integer[]);
DROP FUNCTION table_exists(table_name varchar);
_EOF_
#
#
id = 0
while id < $nparallel
do
  (/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db <<_EOF_
DELETE FROM certificate_generation_info WHERE id % $nparallel = '$id' AND certificate_id NOT IN (SELECT id from certificate);
DELETE FROM certificate_request WHERE id % $nparallel = '$id' AND certificate_request NOT IN (SELECT certificate_request_id from certificate_generation_info);
_EOF_
)&
  id=$(( id + 1 ))
done
#
# Waiting that all the jobs will finish.
#
wait
#
echo "End script:" $( date)
#
#
