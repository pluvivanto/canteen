package main

import (
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
	log.Fatal(http.ListenAndServe(":8080", newHandler()))
}
