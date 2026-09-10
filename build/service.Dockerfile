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
FROM golang:1.25-alpine AS builder
ARG SERVICE
ENV CGO_ENABLED=0 GOOS=linux
WORKDIR /src

# Shared modules first (better layer caching), then the service.
COPY pkg ./pkg
COPY proto ./proto
COPY services/${SERVICE} ./services/${SERVICE}

# The repo's go.work lists every microservice, but only pkg/proto/this
# service are copied into the build context, so a workspace scoped to just
# those three directories is generated here instead of copying go.work.
RUN go work init ./pkg ./proto ./services/${SERVICE}

# Bump transitive dependencies flagged HIGH/CRITICAL by the Trivy image scan:
#   golang.org/x/crypto  < v0.55.0  -> CVE-2026-56854 (SSH auth bypass)
#   google.golang.org/grpc < v1.83.2 -> CVE-2026-84304, CVE-2026-84445
# Applied per module so workspace MVS resolves the patched versions into the
# final binary. Remove once the versions are pinned in the committed go.mod files.
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    ( cd ./pkg && go get golang.org/x/crypto@v0.55.0 google.golang.org/grpc@v1.83.2 ) && \
    ( cd ./proto && go get google.golang.org/grpc@v1.83.2 ) && \
    ( cd ./services/${SERVICE} && go get golang.org/x/crypto@v0.55.0 google.golang.org/grpc@v1.83.2 )

# BuildKit cache mounts share module and compilation cache across builds
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/app ./services/${SERVICE}/cmd

# ---- runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
EXPOSE 8080 9090
ENTRYPOINT ["/app"]
