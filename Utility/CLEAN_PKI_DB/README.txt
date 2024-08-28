The cleanup packege contains four files:

cleanup_db.sh                                 cleanup script
create_function_delete_certificates.sql       sql function definition
delete_certificate_id.sql                     Sql utility file
README.txt                                    This file


Prerequisite:

Connect to running DB (postgres) service group (e.g. db-1 ,  db-2  ... )

  Connect to db-1:
  ssh litp-admin@db-1

  Perform the check where the DB service is running:
  ps -elaf |grep postgres | wc -l

  if return something greater than 1 then db-1 is where the DB is active.
  otherwise connet to other db machine (e.g. db-2) and perform the same check as before

  Do the above procedure unil found the machine where the DB is active.


  When connected to the active DB machine switch to root with following command:

  su -

   In order to remove Inactive, Expired and Revoked certificates a script has been created.

   Extract this package on /tmp

   cd /tmp
   tar xvf cleanup_pki_db.tgz
   cd  CLEANUP_PKI_DB

   Typycal run:

  # default is to work on both (pkicoredb and pkimanagerdb) for inactive,revoked certificates for entity with more than 1000 certificates  of that kind

  ./cleanup_db.sh both expired,revoked,inactive 10 > log.txt 2>&1 &

  The script will run in background and the log can be seen (as an example with tail -f)

      tail -f log.txt


   The script will try to retrieve automatically the postgres password from ENM.
   If not found, the user will be asked for it.

   The above command will remove from pkimanagerdb and pkicoredb all certificates revoked or inactive if they are more than 10 for associated end entity.
   A fix for missing references on the DB is also done.


Examples:

./cleanup_db.sh pkicoredb expired,revoked,inactive 20

   Will remove from pkicoredb all certificates expired,revoked or inactive if they are more than 20 for associated end entity.
   no fix is involved.

./cleanup_db.sh 30 pkimanagerdb  inactive,revoked

   Will remove from pkimanagerdb all certificates revoked or inactive if they are more than 30 for associated end entity.

./cleanup_db.sh revoked,expired 10 both

   Will remove from pkimanagerdb all certificates expired,revoked or inactive if they are more than 10 for associated end entity.


cleanup_db.sh  command syntax:

./cleanup_db.sh [ parameter ] [ parameter ] [ parameter ]

Where parameter can be any of the following types

database(s)
  Database specification: pkicoredb | pkimanagerdb | both

threshold
   Threshold specification: <integer>

states
  Certificate states: <comma separated list of cert_types>

cert_types:    expired  |  inactive | revoked

