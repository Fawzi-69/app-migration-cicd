package main

import (
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
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
	// Faux service "base de données" : un listener TCP local joignable.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("impossible d'ouvrir le listener de test : %v", err)
	}
	defer ln.Close()
	host, port, _ := net.SplitHostPort(ln.Addr().String())

	cases := []struct {
		name     string
		cfg      config
		wantCode int
	}{
		{"db non configurée", config{}, http.StatusServiceUnavailable},
		{"db joignable", config{dbHost: host, dbPort: port}, http.StatusOK},
		{"db injoignable", config{dbHost: "127.0.0.1", dbPort: "1"}, http.StatusServiceUnavailable},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rr := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodGet, "/readyz", nil)
			newTestRouter(tc.cfg).ServeHTTP(rr, req)
			if rr.Code != tc.wantCode {
				t.Errorf("code attendu %d, obtenu %d", tc.wantCode, rr.Code)
			}
		})
	}
}

func TestCheckTCP(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listener : %v", err)
	}
	defer ln.Close()

	if err := checkTCP(ln.Addr().String(), time.Second); err != nil {
		t.Errorf("cible joignable attendue, erreur : %v", err)
	}
	if err := checkTCP("127.0.0.1:1", 200*time.Millisecond); err == nil {
		t.Error("erreur attendue sur cible injoignable")
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
