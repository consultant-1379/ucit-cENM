The cleanup packege contains four files:

clear                                         Clear created log files
create_fix_entity_nocert.sh                   Create a limited time validity executable version of fix_entity_nocert.sh that can be distributed.
fix_entity_nocert.sh                          Check on pki db (pkicoredb pkimanagerdb) for mismatch and fix it if requested by user.
README.txt                                    This file

In order to have an executable that can be used also by customers, run

./create_fix_entity_nocert.sh

This will create enm_fix_postgres_db
It is also possible to create this using the Jenkins job: https://fem27s11-eiffel004.eiffel.gic.ericsson.se:8443/jenkins/job/J-Team_Checkis/


How to run the tool:

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

   download/copy enm_fix_postgres_db on /var/tmp
   run as root the following commands:

     cd /var/tmp
     chmod a+x enm_fix_postgres_db

     ./enm_fix_postgres_db [options] (Seel below)

   Typycal run:

   ./enm_fix_postgres_db info    Will show all the ckeck
   ./enm_fix_postgres_db         Will execute all the checks
   ./enm_fix_postgres_db fix     Will execute all the checks and if available will ask the user (y/n) if he want to fix it,
   ./enm_fix_postgres_db -y fix  Same as previous one but with Yes to all, performing all available fix.


  The script will try to retrieve automatically the postgres password from ENM.
  If not found, the user will be asked for it.


Examples:

./enm_fix_postgres_db

   Will perform a check on the pki DBs (pkicoredb and pkimanagerdb) with a report of references to "missing" certificates

./enm_fix_postgres_db fix

   Same as previous one but will remove the refences to missing certificates.


./cleanup_db.sh pkicoredb expired,revoked,inactive 20

   Will remove from pkicoredb all certificates expired,revoked or inactive if they are more than 20 for associated end entity.
   no fix is involved.

./cleanup_db.sh 30 pkimanagerdb  inactive,revoked

   Will remove from pkimanagerdb all certificates revoked or inactive if they are more than 30 for associated end entity.

./cleanup_db.sh revoked,expired 10 both

   Will remove from pkimanagerdb all certificates expired,revoked or inactive if they are more than 10 for associated end entity.


./clean_pki.sh

   Will perform three operation in sequence.
     first perform a fix on the pki DBs
     then remove from pkimanagerdb and pkicoredb all certificates revoked or inactive if they are more than 1 for associated end entity.
     finally perform another fix to remove possible "dangling" situations.


fix_entity_nocert.sh command syntax:

./enm_fix_postgres_db [fix]
    With "fix" argument will check and fix the pkicoredb and pkimanagerdb
    Otherwise will ust perform the check,



