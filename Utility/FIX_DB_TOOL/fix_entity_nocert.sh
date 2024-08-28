#!/bin/bash
#
ver="0.1.3"
#
nparallel=8
#
if [ -f /proc/cpuinfo ]; then
  ncpu=$(grep '^processor' /proc/cpuinfo | wc -l)
  nparallel=$(( ncpu * 8 / 10 ))
fi
#
# Use parallel processing if more than max_single
#
max_single=2000
#
# check on PG password
#
fix="false"
info="false"
#
echo "Version: $ver"
#
if [ "$1" == "-y" ]; then
  yes="y"
else
  yes=""
fi
#
if [ "$1" == "fix" ]; then
  fix=true
fi
#
if [ "$1" == "info" ]; then
  info=true
else
  date
fi
#
if [ "$1" == "-h" ]; then
  echo "Usage: $0 [-y] [{fix,info}]"
  echo "         Without options will just do the checks."
  echo "    fix  Will fix all issues not tagged as (Check)."
  echo "    info Will show all the checks."
  echo "    -y   answer y to all fix requests."
  echo "    -h   This help."
  exit
fi
#
# print NONE instead of 0.
#
function print_n() {
  if [ "$1" == 0 ]; then
     echo "NONE"
  else
     echo "$1"
  fi
}
#
# perform a query
#
function do_query() {
  if [ "$info" != "true" ]; then
    if [ ! -z "$1" ] && [ ! -z "$2" ]; then
      echo "$2" | /opt/rh/postgresql92/root/usr/bin/psql -U postgres -d $1
    fi
  fi
}
#
# return number of rows of a query
#
function do_and_count_query() {
  if [ "$info" != "true" ]; then
    n=$( ( do_query $1 "$2" ) | grep -A2 'count'  | sed '/^ *$/d' | tail -n 1 | sed 's/  *//g'  )
    if [ -z "$n" ]; then
      echo "-1";
    else
      echo "$n"
    fi
  fi
}
#
# Ask y/n
#
function yes_no() {
  yn="$yes"
  while [ -z "$yn" ]
  do
    read -n 1 -e -a resp -p "Do you want to fix it?: [y/n] [default n] "
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
# Return number of rows that matches a query
#
function print_query_num() {
  n=$(do_and_count_query "$1" "$2")
  if [ "$n" == "-1" ]; then
    echo ""
    n="NO RESULTS ON QUERY: $2"
  fi
  print_n $n
}
#
# Print number of rows of a query
#
function do_and_print_query() {
  if [ "$info" != "true" ]; then
    print_query_num "$1" "$2"
  else
    echo "";
  fi
}
#
# Perform parallel fix if needed.
#
function parallel_fix_db() {
  if echo "$3" | grep -q "WHERE_" ; then
    n=$1
    if [ $n -gt $max_single ]; then
      id=0
      while [ $id -lt $nparallel ]
      do
        new_query=$(echo "$3" | sed "s/WHERE_\([^ ]*\)/WHERE \1 % $nparallel = '$id' AND \1/")
        ( do_query "$2" "$new_query" )&
        id=$(( id + 1 ))
      done
    else
      new_query=$(echo "$3" | sed 's/WHERE_\([^ ]*\)/where /')
      do_query "$2" "$new_query"
    fi
    wait
  else
    echo "Single process $2 $3"
    do_query "$2" "$3"
  fi
}
#
# Perform the query if fix option is provided.
#
function fix_db() {
  if [ "$fix" == "true" ]; then
    if [ ! -z "$1" ] && [ "$1" != "NONE" ]; then
      yn=$( yes_no )
      if [ "$yn" == "y" ]; then
        parallel_fix_db "$1" "$2" "$3"
        echo -n "  -- Fixed"
      else
        echo -n "  -- Skipped"
      fi
    fi
    echo ""
  fi
}
#
# MAIN
#
if [ "$info" != "true" ]; then
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
fi
#
# status_id:
# 1: NEW
# 2: ACTIVE
# 3: INACTIVE
# 4: REISSUE
# 5: DELETED
#
#
db="pkicoredb"
table="entity_info"
#
echo -n "Number of ACTIVE entity without certificates to set to NEW on db: $db: "
#
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 2;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 2;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
###
db="pkimanagerdb"
table="entity"
#
echo -n "Number of ACTIVE entity without certificates to set to NEW on db: $db: "
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 2;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 2;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
######################################
db="pkicoredb"
table="entity_info"
#
echo -n "Number of REVOKED entity without certificates to set to NEW on db: $db: "
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 3;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 3;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
db="pkimanagerdb"
table="entity"
#
echo -n "Number of REVOKED entity without certificates to set to NEW on db: $db: "
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 3;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 3;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
######################################
db="pkicoredb"
table="entity_info"
#
echo -n "Number of INACTIVE entity without certificates to set to NEW on db: $db: "
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 4;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 4;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
###
db="pkimanagerdb"
table="entity"
#
echo -n "Number of INACTIVE entity without certificates to set to NEW on db: $db: "
query="select count(*) from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 4;"
fix_query="update $table set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 4;"
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
######################################
table="certificate_generation_info"
#
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table certificate to remove on db: $db: "
  query="select count(*) from $table where certificate_id not in (select id from certificate);"
  fix_query="delete from $table WHERE_certificate_id not in (select id from certificate);"
  nn=$(do_and_print_query $db "$query") ; echo $nn
  fix_db $nn $db "$fix_query"
done
#
######################################
table="revocation_request_certificate"
#
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table certificate to remove on db: $db: "
  query="select count(*) from $table where certificate_id not in (select id from certificate);"
  fix_query="delete from $table WHERE_certificate_id not in (select id from certificate);"
  nn=$(do_and_print_query $db "$query") ; echo $nn
  fix_db $nn $db "$fix_query"
done
#
######################################
table="revocation_request_certificate"
#
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table revocation_request to remove on db: $db: "
  query="select count(*) from $table where revocation_id not in (select id from revocation_request);"
  fix_query="delete from $table WHERE_revocation_id not in (select id from revocation_request);"
  nn=$(do_and_print_query $db "$query") ; echo $nn
  ## FIX ??
  fix_db $nn $db "$fix_query"
done
#
######################################
#
table="revoked_certificates"
query="select * from $table a, $table b where a.id < b.id AND a.serial_number = b.serial_number;"
fix_query="delete from $table a using $table b where a.id < b.id and a.serial_number = b.serial_number;"
for db in pkicoredb pkimanagerdb
do
  echo "Searching duplicates Serial numbers on table $table on: $db"
  result=$(do_query $db "$query")
  echo "$result"
  n=1
  if echo "$result" | grep -q -e '^(0 rows)$' ; then
    n="NONE"
  fi
  fix_db $n $db "$fix_query"
done
# Extra fix: ALTER TABLE
#
######################################
#
table="revocation_request_revoked_certificate"
query="select count(*) from $table where revoked_certificate_id not in (select id from revoked_certificates);"
fix_query="delete from $table WHERE_revoked_certificate_id not in (select id from revoked_certificates);"
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table revoked_certificates to remove on db: $db: "
  nn=$(do_and_print_query $db "$query") ; echo $nn
  fix_db $nn $db "$fix_query"
done
# Extra fix: ALTER TABLE?
#
######################################
#
table="revocation_request_revoked_certificate"
query="select * from $table a, $table b where a.revocation_id < b.revocation_id AND a.revoked_certificate_id = b.revoked_certificate_id;"
fix_query="delete from $table a using $table b where a.revocation_id < b.revocation_id and a.revoked_certificate_id = b.revoked_certificate_id;"
for db in pkicoredb pkimanagerdb
do
  echo "Searching duplicates revoked_certificate_id on table $table on: $db"
  result=$(do_query $db "$query")
  echo "$result"
  n=1
  if echo "$result" | grep -q -e '^(0 rows)$' ; then
    n="NONE"
  fi
  #fix_db $n $db "$fix_query"
done
# Extra fix: ALTER TABLE?
#
######################################
#
table="entity_certificate"
query="select count(*) from $table where certificate_id not in (select id from certificate);"
fix_query="delete from $table WHERE_certificate_id not in (select id from certificate);"
#
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table certificate on db: $db: "
  nn=$(do_and_print_query $db "$query") ; echo $nn
  fix_db $nn $db "$fix_query"
done
#
######################################
#
db="pkicoredb"
#
table="entity_certificate"
query="select count(*) from $table where entity_id not in (select id from entity_info);"
fix_query="delete from $table WHERE_entity_id not in (select id from entity_info);"
## FIX?
echo -n "Number of rows in $table pointing to not existent entry on table entity_info on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
###
db="pkimanagerdb"
#
table="entity_certificate"
query="select count(*) from $table where entity_id not in (select id from entity);"
fix_query="delete from $table WHERE_entity_id not in (select id from entity);"
echo -n "Number of rows in $table pointing to not existent entry on table entity on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
######################################
#
# Entity IS NOT a CA
#
db="pkicoredb"
#
table="certificate_generation_info"
query="select count(*) from $table where entity_info is not null and entity_info not in (select id from entity_info);"
fix_query="UPDATE $table SET entity_info=(SELECT entity_id FROM entity_certificate WHERE entity_certificate.certificate_id=$table.certificate_id) where entity_info is not null and entity_id not in (select id from entity_info);"
echo -n "(Check) Number of rows in $table pointing to not existent entry on table entity_info to fix on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
## FIX?
# TBD
#fix_db $nn $db "$fix_query"
#
###
db="pkimanagerdb"
#
table="certificate_generation_info"
query="select count(*) from $table where entity_info is not null and entity_info not in (select id from entity);"
fix_query="UPDATE $table SET entity_info=(SELECT entity_id FROM entity_certificate WHERE entity_certificate.certificate_id=$table.certificate_id) where entity_info is not null and entity_info not in (select id from entity);"
echo -n "(Check) Number of rows in $table pointing to not existent entry on table entity to fix on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
## FIX?
#fix_db $nn $db "$fix_query"
# TBD
#
#########
#
# Entity IS a CA
#
db="pkicoredb"
#
table="certificate_generation_info"
query="select count(*) from $table where ca_entity_info is not null and ca_entity_info not in (select id from certificate_authority);"
fix_query="UPDATE $table SET ca_entity_info=(SELECT ca_id FROM ca_certificate WHERE ca_certificate.certificate_id=$table.certificate_id) where ca_entity_info is not null and ca_entity_id not in (select id from certificate_authority);"
#
echo -n "(Check) Number of rows in $table pointing to not existent entry on table caentity to fix on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
#fix_db $nn $db "$fix_query"
## FIX?
# TBD
#
###
db="pkimanagerdb"
#
table="certificate_generation_info"
query="select count(*) from $table where ca_entity_info is not null and ca_entity_info not in (select id from caentity);"
fix_query="UPDATE $table SET ca_entity_info=(SELECT ca_id FROM ca_certificate WHERE ca_certificate.certificate_id=$table.certificate_id) where ca_entity_info is not null and ca_entity_info not in (select id from caentity);"
echo -n "(Check) Number of rows in $table pointing to not existent entry on table caentity to fix on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
#fix_db $nn $db "$fix_query"
## FIX?
# TBD
#
#
######################################
#
table="certificate_request"
query="select count(*) from $table where id not in (select certificate_request_id from certificate_generation_info);"
fix_query="delete from certificate_request WHERE_id not in (select certificate_request_id from certificate_generation_info);"
#
for db in pkicoredb pkimanagerdb
do
  echo -n "Number of rows in $table pointing to not existent entry on table certificate_generation_info to remove on db: $db: "
  nn=$(do_and_print_query $db "$query") ; echo $nn
  fix_db $nn $db "$fix_query"
done
#
######################################
#
db="pkicoredb"
#
table="ca_certificate"
query="select count(*) from $table where ca_id not in (select id from certificate_authority);"
fix_query="delete from $table WHERE_ca_id not in (select id from certificate_authority);"
echo -n "Number of rows in $table pointing to not existent entry on table certificate_authority to remove on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
###
#
db="pkimanagerdb"
#
table="ca_certificate"
query="select count(*) from $table where ca_id not in (select id from caentity);"
fix_query="delete from $table WHERE_ca_id not in (select id from caentity);"
echo -n "Number of rows in $table pointing to not existent entry on table caentity to remove on db: $db: "
nn=$(do_and_print_query $db "$query") ; echo $nn
fix_db $nn $db "$fix_query"
#
###
#
table="ca_certificate"
for db in pkicoredb pkimanagerdb
do
  table="ca_certificate"
  query="select count(*) from $table where certificate_id not in (select id from certificate);"
  ## FIX?
  echo -n "(Check) Number of rows in $table pointing to not existent entry on table certificate to verify on db: $db: "
  nn=$(do_and_print_query $db "$query") ; echo $nn
done
#
############################################################################
#
if [ "$info" != "true" ]; then
  date
  echo "Done"
fi
#
