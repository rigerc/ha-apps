# syntax=docker/dockerfile:1
# Minimal Alpine-based Dockerfile
# This example shows a minimal container using Alpine Linux

FROM alpine:3.21

# Install runtime dependencies only
RUN apk add --no-cache \
    ca-certificates \
    tzdata

# Create non-root user
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser

# Set working directory
WORKDIR /app

# Copy application
COPY --chown=appuser:appuser app .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run application
CMD ["./app"]
