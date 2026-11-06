package main

import (
	"context"
	"database/sql"
	"embed"
	"io/fs"
	"log"
	"net/url"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/pressly/goose/v3/lock"
)

//go:embed migrations/*.sql
var migrations embed.FS

func openDB(ctx context.Context) (*sql.DB, error) {
	dsn := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(os.Getenv("DB_USER"), os.Getenv("DB_PASSWORD")),
		Host:     os.Getenv("DB_HOST") + ":5432",
		Path:     os.Getenv("DB_NAME"),
		RawQuery: "sslmode=require",
	}
	db, err := sql.Open("pgx", dsn.String())
	if err != nil {
		return nil, err
	}
	if err := migrate(ctx, db); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func migrate(ctx context.Context, db *sql.DB) error {
	locker, err := lock.NewPostgresSessionLocker()
	if err != nil {
		return err
	}
	fsys, err := fs.Sub(migrations, "migrations")
	if err != nil {
		return err
	}
	provider, err := goose.NewProvider(goose.DialectPostgres, db, fsys, goose.WithSessionLocker(locker))
	if err != nil {
		return err
	}
	results, err := provider.Up(ctx)
	if err != nil {
		return err
	}
	log.Printf("applied %d migrations", len(results))
	return nil
}
