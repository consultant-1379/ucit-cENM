BEGIN;
SELECT delete_certificates(:ent_id, :threshold, :states);
COMMIT;
