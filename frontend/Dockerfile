# syntax=docker/dockerfile:1
# Build the SPA, then serve it with nginx (which also proxies /api to the gateway).

FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.30-alpine

# Pull the latest Alpine security patches into the base layer. The upstream
# nginx tag is only rebuilt periodically, so it can lag behind Alpine's newest
# point release and ship fixable HIGH/CRITICAL CVEs that fail the Trivy gate.
RUN apk upgrade --no-cache

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
