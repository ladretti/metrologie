package main

import (
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
	Level: slog.LevelDebug,
}))

var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total HTTP requests partitioned by method, path and status code",
		},
		[]string{"method", "path", "status"},
	)

	httpRequestDurationSeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request latency distribution",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)

	appItemsProcessedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "app_items_processed_total",
			Help: "Total items processed by the application",
		},
	)

	appProcessingErrorsTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "app_processing_errors_total",
			Help: "Total processing errors encountered by the application",
		},
	)
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func requestID() string {
	return fmt.Sprintf("%016x", rand.Int63())
}

func instrument(path string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		rid := requestID()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()

		h(rec, r)

		duration := time.Since(start)
		statusStr := strconv.Itoa(rec.status)

		// Métriques Prometheus
		httpRequestsTotal.WithLabelValues(r.Method, path, statusStr).Inc()
		httpRequestDurationSeconds.WithLabelValues(r.Method, path).Observe(duration.Seconds())

		// Log structuré JSON (ingéré par Filebeat → Logstash → Elasticsearch)
		level := slog.LevelInfo
		msg := "request completed"
		if rec.status >= 500 {
			level = slog.LevelError
			msg = "server error"
		} else if rec.status >= 400 {
			level = slog.LevelWarn
			msg = "client error"
		}
		logger.LogAttrs(r.Context(), level, msg,
			slog.String("request_id", rid),
			slog.String("method", r.Method),
			slog.String("path", path),
			slog.Int("status", rec.status),
			slog.Int64("duration_ms", duration.Milliseconds()),
		)
	}
}

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/hello", instrument("/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello, World!")
	}))

	mux.HandleFunc("/error", instrument("/error", func(w http.ResponseWriter, r *http.Request) {
		appProcessingErrorsTotal.Inc()
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}))

	mux.HandleFunc("/not-found", instrument("/not-found", func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "Not Found", http.StatusNotFound)
	}))

	mux.HandleFunc("/work", instrument("/work", func(w http.ResponseWriter, r *http.Request) {
		n := rand.Intn(10) + 1
		time.Sleep(time.Duration(rand.Intn(50)) * time.Millisecond)
		appItemsProcessedTotal.Add(float64(n))
		logger.Info("items processed",
			slog.String("request_id", requestID()),
			slog.String("event_type", "processing"),
			slog.Int("item_count", n),
		)
		fmt.Fprintf(w, "Processed %d items\n", n)
	}))

	mux.Handle("/metrics", promhttp.Handler())

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})

	logger.Info("server starting", slog.String("address", ":8080"))
	if err := http.ListenAndServe(":8080", mux); err != nil {
		logger.Error("server failed", slog.String("error", err.Error()))
	}
}
