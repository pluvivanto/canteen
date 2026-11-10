package main

import (
	"database/sql"
	"errors"
	"log"
	"net/http"
)

func (s *server) issueKey(w http.ResponseWriter, r *http.Request) {
	s.issueKeyFor(w, r, r.PathValue("id"))
}

func (s *server) issueKeyFor(w http.ResponseWriter, r *http.Request, id string) {
	var issuedAt sql.NullTime
	err := s.db.QueryRowContext(r.Context(), "SELECT key_issued_at FROM teams WHERE id = $1", id).Scan(&issuedAt)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "team not found")
		return
	}
	if err != nil {
		log.Printf("get team %s: %v", id, err)
		writeError(w, http.StatusInternalServerError, "could not issue key")
		return
	}

	if issuedAt.Valid {
		if err := s.litellm.deleteKey(id); err != nil {
			log.Printf("delete key of %s in litellm: %v", id, err)
			writeError(w, http.StatusBadGateway, "could not revoke old key")
			return
		}
		if _, err := s.db.ExecContext(r.Context(), "UPDATE teams SET key_issued_at = NULL WHERE id = $1", id); err != nil {
			log.Printf("clear key_issued_at of %s: %v", id, err)
			writeError(w, http.StatusInternalServerError, "could not issue key")
			return
		}
	}

	key, err := s.litellm.generateKey(id)
	if err != nil {
		log.Printf("generate key of %s in litellm: %v", id, err)
		writeError(w, http.StatusBadGateway, "could not generate key")
		return
	}
	if _, err := s.db.ExecContext(r.Context(), "UPDATE teams SET key_issued_at = now() WHERE id = $1", id); err != nil {
		log.Printf("set key_issued_at of %s: %v", id, err)
	}
	writeJSON(w, http.StatusCreated, map[string]string{"key": key})
}
