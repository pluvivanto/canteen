package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/jackc/pgx/v5/pgconn"
)

type team struct {
	ID          string    `json:"id"`
	DisplayName string    `json:"display_name"`
	CreatedAt   time.Time `json:"created_at"`
}

type server struct {
	db      *sql.DB
	litellm *litellm
}

const idAlphabet = "abcdefghijkmnpqrstuvwxyz23456789"

func newTeamID() string {
	b := make([]byte, 6)
	rand.Read(b)
	for i := range b {
		b[i] = idAlphabet[int(b[i])%len(idAlphabet)]
	}
	return "team-" + string(b)
}

func validateDisplayName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", errors.New("display_name is required")
	}
	if utf8.RuneCountInString(name) > 30 {
		return "", errors.New("display_name must be 30 characters or less")
	}
	return name, nil
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func (s *server) createTeam(w http.ResponseWriter, r *http.Request) {
	var req struct {
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	name, err := validateDisplayName(req.DisplayName)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	var t team
	code := newTeamCode()
	for range 3 {
		err = s.db.QueryRowContext(r.Context(),
			"INSERT INTO teams (id, display_name, code_hash) VALUES ($1, $2, $3) RETURNING id, display_name, created_at",
			newTeamID(), name, hashCode(code)).Scan(&t.ID, &t.DisplayName, &t.CreatedAt)
		if !isUniqueViolation(err) {
			break
		}
	}
	if err != nil {
		log.Printf("insert team: %v", err)
		writeError(w, http.StatusInternalServerError, "could not create team")
		return
	}

	if err := s.litellm.createTeam(t.ID, t.DisplayName); err != nil {
		log.Printf("create team %s in litellm: %v", t.ID, err)
		if _, err := s.db.ExecContext(r.Context(), "DELETE FROM teams WHERE id = $1", t.ID); err != nil {
			log.Printf("rollback team %s: %v", t.ID, err)
		}
		writeError(w, http.StatusBadGateway, "could not create team in litellm")
		return
	}
	writeJSON(w, http.StatusCreated, struct {
		team
		Code string `json:"code"`
	}{t, code})
}

func (s *server) listTeams(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), "SELECT id, display_name, created_at FROM teams ORDER BY created_at")
	if err != nil {
		log.Printf("list teams: %v", err)
		writeError(w, http.StatusInternalServerError, "could not list teams")
		return
	}
	defer rows.Close()
	teams := []team{}
	for rows.Next() {
		var t team
		if err := rows.Scan(&t.ID, &t.DisplayName, &t.CreatedAt); err != nil {
			log.Printf("scan team: %v", err)
			writeError(w, http.StatusInternalServerError, "could not list teams")
			return
		}
		teams = append(teams, t)
	}
	if err := rows.Err(); err != nil {
		log.Printf("list teams: %v", err)
		writeError(w, http.StatusInternalServerError, "could not list teams")
		return
	}
	writeJSON(w, http.StatusOK, teams)
}

func (s *server) getTeam(w http.ResponseWriter, r *http.Request) {
	s.writeTeam(w, r, r.PathValue("id"))
}

func (s *server) writeTeam(w http.ResponseWriter, r *http.Request, id string) {
	var t team
	err := s.db.QueryRowContext(r.Context(), "SELECT id, display_name, created_at FROM teams WHERE id = $1",
		id).Scan(&t.ID, &t.DisplayName, &t.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "team not found")
		return
	}
	if err != nil {
		log.Printf("get team: %v", err)
		writeError(w, http.StatusInternalServerError, "could not get team")
		return
	}
	writeJSON(w, http.StatusOK, t)
}

func (s *server) deleteTeam(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var exists bool
	if err := s.db.QueryRowContext(r.Context(), "SELECT EXISTS (SELECT 1 FROM teams WHERE id = $1)", id).Scan(&exists); err != nil {
		log.Printf("check team: %v", err)
		writeError(w, http.StatusInternalServerError, "could not delete team")
		return
	}
	if !exists {
		writeError(w, http.StatusNotFound, "team not found")
		return
	}
	if err := s.litellm.deleteTeam(id); err != nil {
		log.Printf("delete team %s in litellm: %v", id, err)
		writeError(w, http.StatusBadGateway, "could not delete team in litellm")
		return
	}
	if _, err := s.db.ExecContext(r.Context(), "DELETE FROM teams WHERE id = $1", id); err != nil {
		log.Printf("delete team %s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "could not delete team")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
