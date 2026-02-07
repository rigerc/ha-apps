# syntax=docker/dockerfile:1
# Multi-stage build example
# Separates build dependencies from runtime for minimal final image

# Build stage - includes all build tools
FROM node:20-alpine AS build

# Set working directory
WORKDIR /src

# Copy dependency files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage - only runtime dependencies
FROM alpine:3.21 AS production

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    nginx

# Create non-root user
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser

# Copy built assets from build stage
COPY --from=build --chown=appuser:appuser /src/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Run nginx
CMD ["nginx", "-g", "daemon off;"]
