package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

type teamIDKey struct{}

func (s *server) requireTeam(next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		var exists bool
		if err := s.db.QueryRowContext(r.Context(), "SELECT EXISTS (SELECT 1 FROM teams WHERE id = $1)", id).Scan(&exists); err != nil {
			log.Printf("check team: %v", err)
			writeError(w, http.StatusInternalServerError, "could not check team")
			return
		}
		if !exists {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), teamIDKey{}, id)))
	})
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
