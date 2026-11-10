package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
)

func newTeamCode() string {
	b := make([]byte, 12)
	rand.Read(b)
	for i := range b {
		b[i] = idAlphabet[int(b[i])%len(idAlphabet)]
	}
	return string(b[:4]) + "-" + string(b[4:8]) + "-" + string(b[8:])
}

func hashCode(code string) []byte {
	code = strings.NewReplacer("-", "", " ", "").Replace(strings.ToLower(code))
	sum := sha256.Sum256([]byte(code))
	return sum[:]
}

type teamIDKey struct{}

func requireTeamCode(lookup func(ctx context.Context, hash []byte) (string, error), next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		code, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		id, err := lookup(r.Context(), hashCode(code))
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		if err != nil {
			log.Printf("look up team code: %v", err)
			writeError(w, http.StatusInternalServerError, "could not check team code")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), teamIDKey{}, id)))
	})
}

func (s *server) teamIDByCode(ctx context.Context, hash []byte) (string, error) {
	var id string
	err := s.db.QueryRowContext(ctx, "SELECT id FROM teams WHERE code_hash = $1", hash).Scan(&id)
	return id, err
}

func myTeamID(r *http.Request) string {
	return r.Context().Value(teamIDKey{}).(string)
}

func (s *server) getMe(w http.ResponseWriter, r *http.Request) {
	s.writeTeam(w, r, myTeamID(r))
}

func (s *server) updateMe(w http.ResponseWriter, r *http.Request) {
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
	if _, err := s.db.ExecContext(r.Context(), "UPDATE teams SET display_name = $1 WHERE id = $2", name, myTeamID(r)); err != nil {
		log.Printf("rename team %s: %v", myTeamID(r), err)
		writeError(w, http.StatusInternalServerError, "could not rename team")
		return
	}
	s.writeTeam(w, r, myTeamID(r))
}

func (s *server) issueMyKey(w http.ResponseWriter, r *http.Request) {
	s.issueKeyFor(w, r, myTeamID(r))
}

func (s *server) reissueCode(w http.ResponseWriter, r *http.Request) {
	code := newTeamCode()
	res, err := s.db.ExecContext(r.Context(), "UPDATE teams SET code_hash = $1 WHERE id = $2", hashCode(code), r.PathValue("id"))
	if err != nil {
		log.Printf("reissue code of %s: %v", r.PathValue("id"), err)
		writeError(w, http.StatusInternalServerError, "could not reissue code")
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "team not found")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"code": code})
}
