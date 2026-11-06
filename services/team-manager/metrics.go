package main

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	httpRequests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "team_manager_http_requests_total",
		Help: "HTTP requests by route and status code.",
	}, []string{"route", "code"})

	httpDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "team_manager_http_request_duration_seconds",
		Help: "HTTP request duration by route.",
	}, []string{"route"})

	litellmErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "team_manager_litellm_errors_total",
		Help: "Failed calls to LiteLLM by path.",
	}, []string{"path"})
)

type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

func instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" {
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
		next.ServeHTTP(rec, r)
		route := r.Pattern
		if route == "" || route == "/" {
			route = "unmatched"
		}
		httpRequests.WithLabelValues(route, strconv.Itoa(rec.code)).Inc()
		httpDuration.WithLabelValues(route).Observe(time.Since(start).Seconds())
	})
}
