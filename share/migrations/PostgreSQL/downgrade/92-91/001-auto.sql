-- Convert schema '/home/abeverley/git/GADS/share/migrations/_source/deploy/92/001-auto.yml' to '/home/abeverley/git/GADS/share/migrations/_source/deploy/91/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE import DROP CONSTRAINT import_fk_instance_id;

;
DROP INDEX import_idx_instance_id;

;
ALTER TABLE import DROP COLUMN instance_id;

;

COMMIT;

