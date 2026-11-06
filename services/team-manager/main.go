package main

import (
	"context"
	"log"
	"net/http"
)

func newHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})
	return mux
}

func main() {
	db, err := openDB(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	log.Println("listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", newHandler()))
}
