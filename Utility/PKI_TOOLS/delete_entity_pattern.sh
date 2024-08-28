#!/bin/bash
#
#
# WHERE nome ~ '^t(201[0-9]|2020)\d{4}_\d+_\d+$';
#
#entity_name_regex='^t(201[0-9]|2020)\d{4}_\d+_\d+$';
entity_name_regex_enc='_SCRIPT_REGEX_ENC_';
#
entity_name_ver='_SCRIPT_VERSION_'
entity_name_tag='_SCRIPT_TAG_'
entity_name_exp='_SCRIPT_EXPIRES_'
#
entity_name_regex=$(echo "$entity_name_regex_enc"|base64 -d)
#
max_entity=0
max_parallel=8
batch_size=2000
#
if [ -f /proc/cpuinfo ]; then
  ncpu=$(grep '^processor' /proc/cpuinfo | wc -l)
  max_parallel=$(( ncpu * 8 / 10 ))
fi
#
# Ask y/n
#
function yes_no() {
  yn="$yes"
  while [ -z "$yn" ]
  do
    read -n 1 -e -a resp -p "Do you want to continue?: [y/n] [default n] "
    if [ "$resp" == "y" ]; then
      yn="y"
    fi
    if [ "$resp" == "n" ]; then
      yn="n"
    fi
    if [ "$resp" == "" ]; then
      yn="n"
    fi
  done
  echo "$yn"
}
#
function yes_no_exit () {
  ans=$(yes_no)
  if [ $ans == "n" ]; then
    exit
  fi
}
#
function define_sql_create () {
  db=$1
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
function usage () {
  echo "Usage: $0 [-h] [-yes] [-y YYYY[M[M]]] [-b batch_size ] [ -p nparallel ] [pkicoredb|pkimanagerdb|both] [delete]"
  echo "  delete: The matching entity will be deleted"
  echo "  -h:     This help"
  echo "  -yes:   Automatically answer yes to all questions"
  echo "  -b size Min batch size to compute how many process to use (default $batch_size)"
  echo "  -p par  Max parallel process (default: $max_parallel)"
  echo "  -l lim  Max number of entity to process (default: no limit)"
  echo "  -y year Select year and if added month to select."
  echo "          E.g.:  2010   for all entry t2010*"
  echo "                 20120  for all entry t201201* up to t201209"
  echo "  -y year Select year and if added month to select."
  echo "  default: The list of entity name affected by the regex is reported"
  echo ""
  echo "Script version: $entity_name_ver"
  echo "Script tag: $entity_name_tag"
  echo "Script expiratin date: $entity_name_exp"
  echo "Script regex is: $entity_name_regex"
  exit
}
#
function count_entity () {
  db=$1
  count=$2
  if [ "$db" == "pkimanagerdb" ]; then
    entity_table="entity"
  else
    entity_table="entity_info"
  fi
  entity_names=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT id from $entity_table WHERE name ~ '$entity_name_regex' $limit;
_EOF_
  )
  echo "$entity_names" | wc -l
}
#
function select_entity () {
  db=$1
  count=$2
  if [ "$db" == "pkimanagerdb" ]; then
    entity_table="entity"
  else
    entity_table="entity_info"
  fi
  entity_names=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT name from $entity_table WHERE name ~ '$entity_name_regex' $limit;
_EOF_
  )
  n=$(echo "$entity_names" | wc -l)
  echo "Found $n entities on $db:"
  if [ "$count" != "count" ]; then
    echo "$entity_names"
  fi
}
#
function delete_entity_batch  () {
  db=$1
  table=$2
  selector=$3
  parallel_entry=$(( max_entity / nparallel ))
  if [ $max_entity -gt 0 ]; then
    par_limit="LIMIT $parallel_entry"
  else
    par_limit=""
  fi
  entity_ids=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT id from $table where id % $nparallel = $selector AND name ~ '$entity_name_regex' $par_limit;
_EOF_
)
  #
  define_sql_create $db
  #
  n=$(echo "$entity_ids" | wc -l)
  echo "Deleting $n entry($selector) on $db"
  #
  for entity_id in $entity_ids
  do
    #
    # Define functions
    #
    #
    # Execute entity removal.
    #
    echo "Processing ID:$entity_id"
    /opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db << _EOF_
BEGIN;
SELECT delete_entity_certificates($entity_id);
DELETE FROM certificate_generation_info WHERE entity_info = $entity_id;
DELETE FROM revocation_request WHERE entity_id = $entity_id;
DELETE FROM entity_certificate WHERE entity_id = $entity_id;
DELETE FROM $entity_table WHERE id = $entity_id;
COMMIT;
_EOF_
  done
}
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
#
  echo "Start:" $( date )
#
  entity_ids=$(
(/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
SELECT id from $entity_table where name ~ '$entity_name_regex' $limit;
_EOF_
)
#
  num_entities=$(echo "$entity_ids" | wc -l)
  num_batch=$(( num_entities / batch_size ))
  if [ -z "$nparallel" ]; then
    nparallel=$max_parallel
    if [ $num_batch -lt $max_parallel ]; then
      nparallel=$num_batch
    fi
  fi
  echo "Delete on $db will be performed using $nparallel process"

  sel=0
  while [ $sel -lt $nparallel ]
  do
    ( delete_entity_batch $db $entity_table $sel ) &
    sel=$(( sel + 1 ))
  done

  wait
  echo "End:" $( date)
  #
  # Cleanup functions
  #
  (/opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $db | grep '[0-9]$' | sed 's/ //g') <<_EOF_
DROP FUNCTION IF EXISTS delete_entity_certificates(ent_id integer);
DROP FUNCTION IF EXISTS table_exists(table_name varchar);
_EOF_
}
#
function read_num() {
  msg=$1
  num=$2
  if [ -z "$num" ]; then
    echo "$msg"
    usage
  fi
  num=$(( num + 0 ))
  if [ $num -le 0 ]; then
    echo "$msg"
    usage
  fi
  echo $num
}
#
function main() {
  dbname="both"
  threshold=1
  do_it="false"
  #
  year=""
  #
  while [ ! -z "$1" ]
  do
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
      usage
    fi
    if echo "$1" | egrep -q "pkicoredb|pkimanagerdb|both" ; then
      echo "DB=$1"
      dbname="$1"
    fi
    if [ "$1" == "-yes" ]; then
      yes="true"
    fi
    if [ "$1" == "-b" ]; then
      shift
      batch_size=$(read_num "Bad batch size" $1)
    fi
    if [ "$1" == "-l" ]; then
      shift
      max_entity=$(read_num "Bad Max entity" $1)
    fi
    if [ "$1" == "-p" ]; then
      shift
      nparallel=$(read_num "Bad parallel number" $1)
    fi
    if [ "$1" == "-y" ]; then
      shift
      year=$1
      if [ -z "$year" ]; then
        usage
      fi
    fi
    if [ "$1" == "delete" ]; then
      do_it="true"
    fi
    shift
  #
  done
  #
  if [ ! -z "$year" ]; then
    n_year=$(( year + 0 ))
    if [ $n_year -le 0 ]; then
       echo "Bad year entered: '$year'"
       exit
    fi
    entity_name_regex='^t'"$n_year"'\d+_\d+_\d+$'
  fi
  if [ ! -z "$year" ]; then
    if [ -z "$n_year" ]; then
       echo "Can't parse year entered: '$year'"
       exit
    fi
  fi
  #
  echo "Regex is: ${entity_name_regex}"
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
  if [ $max_entity -gt 0 ]; then
    limit="LIMIT $max_entity"
  else
    limit=""
  fi
  db=$dbname
  #
  if [ "$dbname" == "both" ]; then
    if [ "$do_it" == "false" ]; then
      select_entity 'pkicoredb'
      select_entity 'pkimanagerdb'
    else
      select_entity 'pkicoredb' count
      yes_no_exit
      delete_entity 'pkicoredb'
      #
      select_entity 'pkimanagerdb' count
      yes_no_exit
      delete_entity 'pkimanagerdb'
    fi
  else
    if [ "$do_it" == "false" ]; then
      select_entity $dbname
    else
      select_entity $dbname count
      ans=$(yes_no)
      #
      if [ $ans == "n" ]; then
        exit
      fi
      delete_entity $dbname
    fi
  fi
}
#
main $*
#
