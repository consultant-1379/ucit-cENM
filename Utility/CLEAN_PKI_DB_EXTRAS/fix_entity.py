#!/bin/python
#
import psycopg2
import os


query_list=[
    {
        "db":   "pkicoredb",
        "table":"entity_info",
        "msg":  "Number of ACTIVE entity to process on db: {db}: ",
        "query": '''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 2;
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"entity",
        "msg":  "Number of ACTIVE entity to process on db: {db}: ",
        "query":'''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 2;
        '''
    },
######################################
    {
        "db":   "pkicoredb",
        "table":"entity_info",
        "msg":  "Number of INACTIVE entity to process on db: {db}: ",
        "query":'''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 4;
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"entity",
        "msg":  "Number of INACTIVE entity to process on db: {db}: ",
        "query":'''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 4;
        '''
    },

#
######################################
    {
        "db":   "pkicoredb",
        "table":"entity_info",
        "msg":  "Number of REVOKED entity to process on db: {db}: ",
        "query":'''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 3;
        '''
    },


    {
        "db":   "pkimanagerdb",
        "table":"entity",
        "msg":  "Number of REVOKED entity to process on db: {db}: ",
        "query":'''
        select count(*) from {table} e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and status_id = 3;
        '''
    },

######################################
    {
        "db":   "pkicoredb",
        "table":"entity_certificate",
        "msg":  "Number of rows in {table} pointing to not existent entity_info on db: {db}: ",
        "query":'''
        select count(*) from {table} where entity_id not in (select id from entity_info);
        '''
    },


    {
        "db":   "pkicoredb",
        "table":"entity_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

#
######################################
    {
        "db":   "pkicoredb",
        "table":"certificate_generation_info",
        "msg":  "Number of rows in {table} pointing to not existent certificate to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where entity_info not in (select id from entity_info);
        '''
    },


    {
        "db":"pkimanagerdb",
        "table":"certificate_generation_info",
        "msg": "Number of rows in {table} pointing to not existent certificate to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where entity_info not in (select id from entity);
        '''
    },

######################################
    {
        "db":   "pkicoredb",
        "table":"certificate_generation_info",
        "msg":  "Number of rows in {table} pointing to not existent certificate to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"certificate_generation_info",
        "msg":  "Number of rows in {table} pointing to not existent certificate to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },


#
######################################
    {
        "db":   "pkicoredb",
        "table":"certificate_request",
        "msg":  "Number of rows in {table} pointing to not existent certificate_generation_info to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where id not in (select certificate_request_id from certificate_generation_info);
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"certificate_request",
        "msg":  "Number of rows in {table} pointing to not existent certificate_generation_info to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where id not in (select certificate_request_id from certificate_generation_info);
        '''
    },

######################################
    {
        "db":   "pkicoredb",
        "table":"revocation_request_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate_id to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"revocation_request_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate_id to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

######################################
    {
        "db":   "pkicoredb",
        "table":"ca_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate_id to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

    {
        "db":   "pkicoredb",
        "table":"ca_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate_authority on db: {db}: ",
        "query":'''
        select count(*) from {table} where ca_id not in (select id from certificate_authority);
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"ca_certificate",
        "msg":  "Number of rows in {table} pointing to not existent certificate_id to process on db: {db}: ",
        "query":'''
        select count(*) from {table} where certificate_id not in (select id from certificate);
        '''
    },

    {
        "db":   "pkimanagerdb",
        "table":"ca_certificate",
        "msg":  "Number of rows in {table} pointing to not existent caentity on db: {db}: ",
        "query":'''
        select count(*) from {table} where ca_id not in (select id from caentity);
        '''
    }
]

#
######################################
#
# Do the real work if requested
#
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 2;
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 2;
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 3;
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 3;
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 4;
# update {table} set status_id = 1 from $table e left join (select entity_id,count(certificate_id) as count from entity_certificate group by entity_id) entity_cert on entity_cert.entity_id=e.id where count IS NULL and $table.id = e.id and e.status_id = 4;
# delete from {table} where certificate_id not in (select id from certificate);
# delete from {table} where certificate_id not in (select id from certificate);
# DELETE FROM certificate_generation_info WHERE id % 20 = '$n' AND certificate_id NOT IN (SELECT id from certificate);
# DELETE FROM certificate_request WHERE id % 20 = '$n' AND id NOT IN (SELECT certificate_request_id from certificate_generation_info);
# DELETE FROM {table} where certificate_id not in (select id from certificate);
# DELETE FROM {table} where certificate_id not in (select id from certificate);


def psql_connect(db):
    try:
        # connecting to the PostgreSQL server
        with psycopg2.connect(
                    host="localhost",
                    database=db,
                    user="postgres",
                    password=os.environ['PGPASSWORD'] ) as conn:
                        print('Connected to the PostgreSQL server.')
                        return conn
    except (psycopg2.DatabaseError, Exception) as error:
        print(error)

def make_query(db, query):
    conn = psql_connect(db)
    cursor = conn.cursor()
    cursor.execute(query)
    ret=0
    for rec in cursor.fetchall():
        ret = rec[0]
    conn.close()
    return ret


def main():
    for itm in query_list:
        db=itm["db"]
        table=itm["table"]
        msg=itm["msg"].format(db=db, table=table)
        query=itm["query"].format(db=db, table=table)
        xx='Working on {db} table {table}'.format(db=db, table=table)
        print(xx)
        ret=make_query(db,query)
        print(msg, ret)
	print("##################")


if __name__ == "__main__":
    main()
