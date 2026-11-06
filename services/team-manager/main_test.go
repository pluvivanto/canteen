package main

import (
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	newHandler(&server{}, "secret").ServeHTTP(rec, httptest.NewRequest("GET", "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if rec.Body.String() != "ok" {
		t.Fatalf("body = %q, want %q", rec.Body.String(), "ok")
	}
}

func TestRequireToken(t *testing.T) {
	tests := []struct {
		header string
		want   int
	}{
		{"", http.StatusUnauthorized},
		{"Bearer wrong", http.StatusUnauthorized},
		{"secret", http.StatusUnauthorized},
		{"Bearer secret", http.StatusTeapot},
	}
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTeapot) })
	for _, tt := range tests {
		req := httptest.NewRequest("GET", "/teams", nil)
		req.Header.Set("Authorization", tt.header)
		rec := httptest.NewRecorder()
		requireToken("secret", next).ServeHTTP(rec, req)
		if rec.Code != tt.want {
			t.Errorf("header %q: status = %d, want %d", tt.header, rec.Code, tt.want)
		}
	}
}

func TestNewTeamID(t *testing.T) {
	pattern := regexp.MustCompile(`^team-[a-km-np-z2-9]{6}$`)
	for range 1000 {
		if id := newTeamID(); !pattern.MatchString(id) {
			t.Fatalf("id %q does not match %s", id, pattern)
		}
	}
}

func TestValidateDisplayName(t *testing.T) {
	tests := []struct {
		in      string
		want    string
		wantErr bool
	}{
		{"Foo Bar", "Foo Bar", false},
		{"  Foo Bar  ", "Foo Bar", false},
		{"", "", true},
		{"   ", "", true},
		{strings.Repeat("a", 30), strings.Repeat("a", 30), false},
		{strings.Repeat("a", 31), "", true},
		{strings.Repeat("가", 30), strings.Repeat("가", 30), false},
	}
	for _, tt := range tests {
		got, err := validateDisplayName(tt.in)
		if (err != nil) != tt.wantErr || got != tt.want {
			t.Errorf("validateDisplayName(%q) = %q, %v; want %q, wantErr %v", tt.in, got, err, tt.want, tt.wantErr)
		}
	}
}

func TestInstrumentUsesRoutePattern(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /teams/{id}", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTeapot) })
	instrument(mux).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/teams/team-abc", nil))

	if got := testutil.ToFloat64(httpRequests.WithLabelValues("GET /teams/{id}", "418")); got != 1 {
		t.Fatalf("requests{route=GET /teams/{id}, code=418} = %v, want 1", got)
	}
}
