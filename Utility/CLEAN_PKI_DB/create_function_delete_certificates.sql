-- Stored function for deleting 'pkiraserv' service group's inactive, revoked or expired certificates
DROP FUNCTION IF EXISTS table_exists(table_name varchar);
CREATE FUNCTION table_exists(table_name varchar) RETURNS bool AS $$
BEGIN
    BEGIN
        EXECUTE format('SELECT * FROM %I LIMIT 0', table_name);
        RETURN true;
    EXCEPTION WHEN undefined_table THEN
        RETURN false;
    END;
END $$
LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS delete_cert_id(cert_id bigint, states integer[]);
CREATE FUNCTION delete_cert_id(cert_id bigint, states integer[]) RETURNS void AS $$
DECLARE
   cert_ids       BIGINT[];
   sub_cert_id    BIGINT;
   revocation_ids BIGINT[];
   rev_id         BIGINT;
BEGIN
--    SELECT INTO cert_ids array_agg(cert.id) FROM certificate cert WHERE cert.status_id = ANY( states ) AND cert.issuer_id = cert_id;
--    IF cert_ids IS NOT NULL
--    THEN
--        FOREACH sub_cert_id IN ARRAY cert_ids
--        LOOP
--            RAISE WARNING 'Working on sub_cert_id: %', sub_cert_id;
--            IF cert_id != sub_cert_id
--            THEN
--              RAISE WARNING 'Calling delete_cert_id on sub_cert_id: % issued by: % ', sub_cert_id, cert_id;
--              PERFORM delete_cert_id(sub_cert_id, states);
--            END IF;
--        END LOOP;
--    END IF;
    DELETE FROM entity_certificate WHERE certificate_id = cert_id;
    DELETE FROM certificate_generation_info WHERE certificate_id = cert_id;

    SELECT INTO revocation_ids array_agg(revocation_id) FROM revocation_request_certificate WHERE certificate_id = cert_id;
    IF revocation_ids IS NOT NULL
    THEN
        FOREACH rev_id IN ARRAY revocation_ids
        LOOP

-- RAISE WARNING 'Working on cert_id:% rev_id: %', cert_id, rev_id;
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
    IF table_exists('crl_generation_info_ca_certificate') THEN
      DELETE FROM crl_generation_info_ca_certificate WHERE certificate_id = cert_id;
    END IF;
    DELETE FROM certificate WHERE id = cert_id;
--     RAISE WARNING 'Deleted related tables to cerrificate cert_id: %', cert_id;
END $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_certificates(ent_id integer, threshold integer, VARIADIC states integer[]) RETURNS void as $$
DECLARE
   cert_id        BIGINT;
   cert_ids       BIGINT[];
BEGIN

    SELECT INTO cert_ids array_agg(out_cert.id) FROM certificate out_cert WHERE out_cert.status_id = ANY( states ) AND out_cert.id IN (SELECT ent_cert.certificate_id FROM entity_certificate ent_cert WHERE ent_cert.entity_id IN (ent_id));

    IF cert_ids IS NOT NULL
    THEN
        IF array_length(cert_ids, 1) > threshold then
            RAISE WARNING 'Working on ent_id: % with size: %', ent_id, array_length(cert_ids, 1);
            FOREACH cert_id IN ARRAY cert_ids
            LOOP
   RAISE WARNING 'Working on cert_id: % for ent_id: %', cert_id, ent_id;
                PERFORM delete_cert_id(cert_id, states);
            END LOOP;
        END IF;
    END IF;
END;
$$
LANGUAGE plpgsql;
