# syntax=docker/dockerfile:1
# Multi-platform build example with cross-compilation
# Builds for multiple architectures using native compilation

# Build stage - pinned to builder platform
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build

# Declare build arguments for target platform
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Set working directory
WORKDIR /src

# Copy go mod files first for better caching
COPY go.* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build for target platform
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT} \
    go build -ldflags="-w -s" -o /app .

# Final stage - minimal runtime
FROM alpine:3.21

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser

# Copy binary from build stage
COPY --from=build /app /usr/local/bin/app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run application
CMD ["app"]

# Build commands:
# docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
# docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t myapp:latest --push.
