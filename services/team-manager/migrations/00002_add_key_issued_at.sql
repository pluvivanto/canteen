-- +goose Up
ALTER TABLE teams ADD COLUMN key_issued_at timestamptz;

-- +goose Down
ALTER TABLE teams DROP COLUMN key_issued_at;
