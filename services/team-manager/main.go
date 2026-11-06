package main

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func requireToken(token string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got := r.Header.Get("Authorization")
		if subtle.ConstantTimeCompare([]byte(got), []byte("Bearer "+token)) != 1 {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func newHandler(s *server, adminToken string) http.Handler {
	api := http.NewServeMux()
	api.HandleFunc("POST /teams", s.createTeam)
	api.HandleFunc("GET /teams", s.listTeams)
	api.HandleFunc("GET /teams/{id}", s.getTeam)
	api.HandleFunc("DELETE /teams/{id}", s.deleteTeam)
	api.HandleFunc("POST /teams/{id}/keys", s.issueKey)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})
	mux.Handle("/", requireToken(adminToken, api))
	return instrument(mux)
}

func main() {
	adminToken := os.Getenv("ADMIN_TOKEN")
	if adminToken == "" {
		log.Fatal("ADMIN_TOKEN is required")
	}

	db, err := openDB(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	s := &server{db: db, litellm: newLiteLLM(os.Getenv("LITELLM_URL"), os.Getenv("LITELLM_MASTER_KEY"))}
	go func() {
		log.Fatal(http.ListenAndServe(":9090", promhttp.Handler()))
	}()
	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", newHandler(s, adminToken)))
}
