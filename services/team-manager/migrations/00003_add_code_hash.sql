-- +goose Up
ALTER TABLE teams ADD COLUMN code_hash bytea UNIQUE;

-- +goose Down
ALTER TABLE teams DROP COLUMN code_hash;
