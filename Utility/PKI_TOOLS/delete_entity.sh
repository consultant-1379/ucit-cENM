#!/bin/bash
#
entity_name_list="_ENTITY_NAME_"
#
function define_sql_create () {
#
/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db <<_EOF_
-- Stored function for deleting 'pkiraserv' service group's inactive, revoked or expired certificates
DROP FUNCTION IF EXISTS table_exists(table_name varchar);
CREATE FUNCTION table_exists(table_name varchar) RETURNS bool AS \$$
BEGIN
    BEGIN
        EXECUTE format('SELECT * FROM %I LIMIT 0', table_name);
        RETURN true;
    EXCEPTION WHEN undefined_table THEN
        RETURN false;
    END;
END \$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_entity_certificates(ent_id integer) RETURNS void as \$$
DECLARE
   cert_id        BIGINT;
   cert_ids       BIGINT[];
   rev_id         BIGINT;
   revocation_ids BIGINT[];
BEGIN

    SELECT INTO cert_ids array_agg(out_cert.id) FROM certificate out_cert WHERE out_cert.id IN (SELECT ent_cert.certificate_id FROM entity_certificate ent_cert WHERE ent_cert.entity_id IN (ent_id));

    IF cert_ids IS NOT NULL
    THEN
            RAISE WARNING 'Working on ent_id: % with size: %', ent_id, array_length(cert_ids, 1);
            FOREACH cert_id IN ARRAY cert_ids
            LOOP

-- RAISE WARNING 'Working on cert_id: % for ent_id: %', cert_id, ent_id;

                DELETE FROM entity_certificate WHERE certificate_id = cert_id;
                DELETE FROM certificate_generation_info WHERE certificate_id = cert_id;

                SELECT INTO revocation_ids array_agg(revocation_id) FROM revocation_request_certificate WHERE certificate_id = cert_id;
                IF revocation_ids IS NOT NULL
                THEN
                    FOREACH rev_id IN ARRAY revocation_ids
                    LOOP

-- RAISE WARNING 'Working on cert_id:% rev_id: % ent_id: %', cert_id, rev_id, ent_id;
			IF table_exists('revoked_certificates') THEN
                          DELETE FROM revoked_certificates WHERE id IN ( SELECT revoked_certificate_id FROM revocation_request_revoked_certificate WHERE revocation_id = rev_id);
			END IF;
			IF table_exists('revocation_request_revoked_certificate') THEN
                          DELETE FROM revocation_request_revoked_certificate WHERE revocation_id = rev_id;
			END IF;
			IF table_exists('revocation_request_certificate') THEN
                          DELETE FROM revocation_request_certificate WHERE revocation_id = rev_id;
			END IF;
			IF table_exists('revocation_request') THEN
                          DELETE FROM revocation_request WHERE id IN (rev_id);
			END IF;
                    END LOOP;
                END IF;
                DELETE FROM certificate WHERE id = cert_id;
            END LOOP;
    END IF;
END;
\$$
LANGUAGE plpgsql;
_EOF_
#
}
#
dbname="both"
threshold=1
#
echo "$0 $*"
#
while [ ! -z "$1" ]
do
  if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Usage: $0 [pkicoredb|pkimanagerdb|both]"
    exit
  fi
  if echo "$1" | egrep -q "pkicoredb|pkimanagerdb|both" ; then
    echo "DB=$1"
    dbname="$1"
    shift
  fi
done
#
#
# check on PG password
echo READ PASS
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
db=$dbname
#
function delete_entity () {
db=$1
#
echo "Working on $db"
#
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
DROP FUNCTION IF EXISTS delete_entity_certificates(ent_id integer);
DROP FUNCTION IF EXISTS table_exists(table_name varchar);
_EOF_
#
#
if [ "$db" == "pkimanagerdb" ]; then
  entity_table="entity"
else
  entity_table="entity_info"
fi
entity_id=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT id from $entity_table where name = '$entity_name';
_EOF_
)
#select id from entity_info where name = '70805';
#
#
if [ $(echo "$entity_id" | wc -w) == 1 ]; then
  #
  # Define functions
  #
  define_sql_create $db
  #
  # Execute entity removal.
  #
  echo "Start:" $( date )
  echo "Processing ID:$id (name=$entity_name"
  /opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db << _EOF_
BEGIN;
SELECT delete_entity_certificates($entity_id);
DELETE FROM certificate_generation_info WHERE entity_info = $entity_id;
DELETE FROM revocation_request WHERE entity_id = $entity_id;
DELETE FROM entity_certificate WHERE entity_id = $entity_id;
DELETE FROM $entity_table WHERE id = $entity_id;
COMMIT;
_EOF_
  echo "End:" $( date)
  #
  # Cleanup functions
  #
  (/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
DROP FUNCTION IF EXISTS delete_entity_certificates(ent_id integer);
DROP FUNCTION IF EXISTS table_exists(table_name varchar);
_EOF_
else
  if [ ! -z "$entity_id" ]; then
    echo "Too many entity found for $entity_name: $entity_id"
  else
    echo "No entity: $entity_name found"
  fi
fi
#
}
#
for e in $(sed 's/,/ /g' <<< $entity_name_list)
do
  entity_name=$e
  if [ "$dbname" == "both" ]; then
    delete_entity 'pkicoredb'
    delete_entity 'pkimanagerdb'
  else
    delete_entity $dbname
  fi
done
#
