# syntax=docker/dockerfile:1

# --- Étape 1 : compilation -------------------------------------------------
# Image de build complète (toolchain Go). Elle n'est PAS embarquée dans
# l'image finale : seul le binaire compilé est copié à l'étape suivante.
FROM golang:1.23-alpine AS builder

WORKDIR /src

# Couche de dépendances mise en cache séparément du code source.
COPY go.mod ./
# (pas de go.sum : application sans dépendance externe)
RUN go mod download

COPY . .

# Binaire statique, sans CGO, dépouillé de ses symboles de debug (-s -w)
# pour réduire la taille et la surface.
ARG APP_VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${APP_VERSION}" \
    -o /out/app .

# --- Étape 2 : image d'exécution -------------------------------------------
# distroless "nonroot" : pas de shell, pas de gestionnaire de paquets,
# utilisateur non privilégié (uid 65532) par défaut. Surface d'attaque minimale.
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app
COPY --from=builder /out/app /app/app

# Exécution en utilisateur non-root (imposé, en plus du défaut de l'image).
USER 65532:65532

EXPOSE 8080
ENV PORT=8080

# Sonde de conteneur : appelle le mode healthcheck intégré au binaire
# (aucune commande externe disponible dans une image distroless).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/app/app", "healthcheck"]

ENTRYPOINT ["/app/app"]
