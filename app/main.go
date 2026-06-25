// Commande de l'API de démonstration migrée vers AWS.
//
// Volontairement minimale et sans dépendance externe (bibliothèque standard
// uniquement) : l'objectif est de mettre en valeur la chaîne de conteneurisation
// et d'industrialisation, pas la logique métier. L'API expose les sondes
// attendues par un orchestrateur de conteneurs (liveness / readiness) et un
// arrêt gracieux compatible avec le cycle de vie d'une tâche ECS Fargate.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// version est injectée à la compilation via -ldflags "-X main.version=...".
// Sert de valeur par défaut si APP_VERSION n'est pas fournie à l'exécution.
var version = "dev"

// config regroupe les paramètres lus dans l'environnement au démarrage.
// Les valeurs sensibles (identifiants base de données, secret applicatif) sont
// injectées par ECS depuis AWS Secrets Manager : elles ne sont jamais écrites
// en dur ni journalisées.
type config struct {
	port    string
	env     string
	version string
	// dbURL n'est lu que pour valider sa présence (sonde readiness). Sa valeur
	// n'est jamais journalisée.
	dbURL string
}

func loadConfig() config {
	return config{
		port:    getenv("PORT", "8080"),
		env:     getenv("APP_ENV", "local"),
		version: getenv("APP_VERSION", version),
		dbURL:   os.Getenv("DATABASE_URL"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	cfg := loadConfig()

	// Mode sonde : `app healthcheck` interroge l'instance locale puis sort avec
	// un code de retour 0/1. Utilisé par l'instruction HEALTHCHECK du Dockerfile,
	// car l'image distroless ne contient ni shell ni curl/wget.
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(runHealthcheck(cfg.port))
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	srv := &http.Server{
		Addr:              ":" + cfg.port,
		Handler:           newRouter(cfg, logger),
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Démarrage non bloquant pour pouvoir intercepter les signaux d'arrêt.
	go func() {
		logger.Info("démarrage du serveur", "port", cfg.port, "env", cfg.env, "version", cfg.version)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("arrêt inattendu du serveur", "err", err)
			os.Exit(1)
		}
	}()

	// Arrêt gracieux : ECS envoie SIGTERM puis attend la fin de la tâche.
	// On laisse 10 s aux requêtes en cours pour se terminer.
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	logger.Info("signal d'arrêt reçu, drainage des connexions")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("arrêt gracieux échoué", "err", err)
		os.Exit(1)
	}
	logger.Info("serveur arrêté proprement")
}

// newRouter construit le multiplexeur HTTP. Isolé du main pour être testable.
func newRouter(cfg config, logger *slog.Logger) http.Handler {
	mux := http.NewServeMux()

	// Sonde de vivacité (liveness) : le process répond.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Sonde de disponibilité (readiness) : les dépendances requises sont là.
	// Ici, on exige la présence de l'URL de base de données injectée par
	// Secrets Manager. Tant qu'elle manque, l'instance n'est pas prête.
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if cfg.dbURL == "" {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{
				"status": "not-ready",
				"reason": "configuration base de données absente",
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	// Endpoint de démonstration : renvoie quelques métadonnées d'exécution.
	mux.HandleFunc("GET /", func(w http.ResponseWriter, _ *http.Request) {
		host, _ := os.Hostname()
		writeJSON(w, http.StatusOK, map[string]string{
			"app":      "app-migration-cicd",
			"env":      cfg.env,
			"version":  cfg.version,
			"hostname": host,
		})
	})

	return logRequests(logger, mux)
}

// logRequests journalise chaque requête au format structuré (JSON).
func logRequests(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Info("requête",
			"method", r.Method,
			"path", r.URL.Path,
			"duration_ms", time.Since(start).Milliseconds(),
		)
	})
}

// runHealthcheck interroge la sonde de vivacité locale. Retourne 0 si l'API
// répond 200, 1 sinon. Aucune dépendance externe requise.
func runHealthcheck(port string) int {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%s/healthz", port))
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
