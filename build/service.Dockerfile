# syntax=docker/dockerfile:1
#
# Single parameterized build for every banking-platform microservice.
# Build from the repository ROOT, selecting the service via --build-arg:
#
#   docker build -f build/service.Dockerfile --build-arg SERVICE=auth-service \
#       -t banking/auth-service:dev .
#
# The distroless "nonroot" final image runs as a non-root user with no shell.

ARG SERVICE

# ---- build stage ----
FROM golang:1.24-alpine AS builder
ARG SERVICE
ENV CGO_ENABLED=0 GOOS=linux
WORKDIR /src

# Shared modules + workspace definition first, then the service.
COPY go.work ./
COPY pkg ./pkg
COPY proto ./proto
COPY services/${SERVICE} ./services/${SERVICE}

# BuildKit cache mounts share module and compilation cache across builds
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/app ./services/${SERVICE}/cmd

# ---- runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
EXPOSE 8080 9090
ENTRYPOINT ["/app"]
