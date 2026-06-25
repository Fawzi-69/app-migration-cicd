package main

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

// newTestRouter monte le routeur avec un logger silencieux.
func newTestRouter(cfg config) http.Handler {
	return newRouter(cfg, slog.New(slog.NewJSONHandler(io.Discard, nil)))
}

func TestHealthz(t *testing.T) {
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	newTestRouter(config{}).ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("code attendu 200, obtenu %d", rr.Code)
	}
	var body map[string]string
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("réponse JSON invalide : %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status attendu \"ok\", obtenu %q", body["status"])
	}
}

func TestReadyz(t *testing.T) {
	cases := []struct {
		name     string
		dbURL    string
		wantCode int
	}{
		{"sans base de données", "", http.StatusServiceUnavailable},
		{"avec base de données", "postgres://localhost/db", http.StatusOK},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rr := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
			newTestRouter(config{dbURL: tc.dbURL}).ServeHTTP(rr, req)
			if rr.Code != tc.wantCode {
				t.Errorf("code attendu %d, obtenu %d", tc.wantCode, rr.Code)
			}
		})
	}
}

func TestRootReturnsMetadata(t *testing.T) {
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	newTestRouter(config{env: "test", version: "1.2.3"}).ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("code attendu 200, obtenu %d", rr.Code)
	}
	var body map[string]string
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("réponse JSON invalide : %v", err)
	}
	if body["env"] != "test" || body["version"] != "1.2.3" {
		t.Errorf("métadonnées inattendues : %+v", body)
	}
}

func TestGetenvFallback(t *testing.T) {
	t.Setenv("UNE_VAR_DEFINIE", "valeur")
	if got := getenv("UNE_VAR_DEFINIE", "defaut"); got != "valeur" {
		t.Errorf("attendu \"valeur\", obtenu %q", got)
	}
	if got := getenv("VAR_ABSENTE", "defaut"); got != "defaut" {
		t.Errorf("attendu \"defaut\", obtenu %q", got)
	}
}
