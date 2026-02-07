---
name: dockerfile
description: This skill should be used when the user asks to "create a Dockerfile", "write a Dockerfile", "build a Docker image", "containerize an application", "optimize a Dockerfile", or mentions Dockerfiles, container images, multi-stage builds, or Docker best practices.
version: 0.1.0
---

# Dockerfile

Comprehensive guidance for creating, optimizing, and maintaining Dockerfiles following Docker best practices and BuildKit patterns.

## Purpose

Create efficient, secure, and maintainable Dockerfiles that follow Docker best practices. This skill covers Dockerfile fundamentals, multi-stage builds, build optimization, base image selection, and production-ready patterns.

## When to Use This Skill

Use this skill when:
- Creating a new Dockerfile for an application
- Optimizing an existing Dockerfile for size or performance
- Implementing multi-stage builds
- Setting up multi-platform image builds
- Troubleshooting Docker build issues
- Converting application deployments to containers
- Implementing build caching strategies
- Configuring build arguments and environment variables

## Core Workflow

### Step 1: Start with Syntax Directive

Always begin the Dockerfile with the syntax parser directive:

```dockerfile
# syntax=docker/dockerfile:1
```

This directive ensures the Dockerfile uses the latest stable version 1 syntax. The directive must appear before any comments, whitespace, or instructions.

### Step 2: Choose the Right Base Image

Select a base image that matches the application requirements:

**For minimal images:** Use `alpine` or `scratch`
```dockerfile
FROM alpine:3.21
```

**For official languages:** Use Docker Official Images
```dockerfile
FROM node:20-alpine
FROM python:3.12-slim
FROM golang:1.23-alpine
```

**For production:** Pin to specific digest for reproducibility
```dockerfile
FROM alpine:3.21@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
```

Prefer Official Images, Verified Publisher images, or minimal variants (`-slim`, `-alpine`) to reduce attack surface and image size.

### Step 3: Structure with Multi-Stage Builds

Use multi-stage builds to separate build dependencies from runtime dependencies:

```dockerfile
# syntax=docker/dockerfile:1

FROM node:20-alpine AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM alpine:3.21 AS production
WORKDIR /app
COPY --from=build /src/dist ./dist
CMD ["nginx", "-g", "daemon off;"]
```

Name stages using `AS` for clarity. Copy only required artifacts using `COPY --from=stage-name`.

### Step 4: Optimize Layer Caching

Order instructions to maximize cache hits:

1. Copy dependency files first (`package.json`, `requirements.txt`, `go.mod`)
2. Install dependencies (changes less frequently)
3. Copy source code (changes more frequently)

```dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
```

Chain related commands with `&&` to reduce layers:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package-bar \
    package-baz \
    && rm -rf /var/lib/apt/lists/*
```

### Step 5: Set Working Directory and User

Define the working directory and run as non-root user when possible:

```dockerfile
WORKDIR /app
RUN addgroup -g 1000 -S appuser && adduser -u 1000 -S appuser -G appuser
USER appuser
```

Use absolute paths for `WORKDIR`. Create users with explicit UID/GID when required for consistency.

### Step 6: Expose Ports and Define Entrypoint

Document exposed ports and define how the container starts:

```dockerfile
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["./app"]
CMD ["--config", "/etc/config.yaml"]
```

Use `ENTRYPOINT` for the main executable and `CMD` for default arguments. Use the exec form (JSON array) for proper signal handling.

### Step 7: Build for Multiple Platforms (Optional)

For multi-platform support, use platform-aware build arguments:

```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETOS
ARG TARGETARCH
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o app .

FROM alpine:3.21
COPY --from=build /app /
CMD ["./app"]
```

Build with: `docker build --platform linux/amd64,linux/arm64 .`

## Build Variables

### Build Arguments (ARG)

Use `ARG` for build-time configuration:

```dockerfile
ARG NODE_VERSION=20
ARG ALPINE_VERSION=3.21

FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION}
```

Build arguments declared globally aren't automatically inherited into stages. Consume them explicitly:

```dockerfile
ARG VERSION=1.0.0
FROM alpine:3.21
# Must consume ARG to use it in stage
ARG VERSION
RUN echo $VERSION
```

### Environment Variables (ENV)

Use `ENV` for runtime configuration:

```dockerfile
ENV NODE_ENV=production
ENV PATH="/usr/local/bin:${PATH}"
```

Combine `ARG` and `ENV` for configurable environment variables:

```dockerfile
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
```

Build with: `docker build --build-arg NODE_ENV=development .`

### Pre-Defined Build Arguments

BuildKit provides these automatically:
- `BUILDPLATFORM`, `BUILDOS`, `BUILDARCH`, `BUILDVARIANT` - Builder platform
- `TARGETPLATFORM`, `TARGETOS`, `TARGETARCH`, `TARGETVARIANT` - Target platform

## Common Patterns

### apt-get Pattern

For Debian-based images:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*
```

Always combine `update` and `install` in one `RUN` instruction. Use `--no-install-recommends` to reduce size. Clean up apt cache.

### pip Pattern

For Python applications:

```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

### npm Pattern

For Node.js applications:

```dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
```

Use `npm ci` instead of `npm install` for reproducible builds.

### Go Pattern

For Go applications with cross-compilation:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETOS
ARG TARGETARCH
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o app .

FROM alpine:3.21
COPY --from=build /app /
CMD ["./app"]
```

## Best Practices

1. **Use multi-stage builds** - Separate build and runtime dependencies
2. **Choose minimal base images** - Prefer alpine, slim variants, or scratch
3. **Leverage build cache** - Order instructions from least to most frequently changing
4. **Chain RUN commands** - Combine related commands to reduce layers
5. **Use .dockerignore** - Exclude unnecessary files from build context
6. **Pin base images** - Use specific tags or digests for reproducibility
7. **Run as non-root** - Create and use a non-privileged user
8. **Use exec form** - JSON array syntax for CMD, ENTRYPOINT, RUN
9. **Add HEALTHCHECK** - Define container health status
10. **Scan for vulnerabilities** - Use Docker Scout or similar tools

## Troubleshooting

### Build Cache Issues

Use `--no-cache` to bypass build cache:
```bash
docker build --no-cache -t image:tag .
```

Use `--pull` to fetch fresh base images:
```bash
docker build --pull -t image:tag .
```

### Debugging Multi-Stage Builds

Stop at a specific stage:
```bash
docker build --target build-stage-name -t debug:tag .
```

### Platform Build Issues

Verify QEMU is installed for cross-platform builds:
```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

### Layer Size Analysis

Inspect image layers:
```bash
docker history image:tag
```

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/instructions.md`** - Complete Dockerfile instruction reference
- **`references/best-practices.md`** - Extended best practices guide
- **`references/multi-platform.md`** - Multi-platform build strategies
- **`references/build-cache.md`** - Build cache optimization techniques
- **`references/security.md`** - Security considerations and scanning

### Example Files

Working examples in `examples/`:
- **`examples/alpine.Dockerfile`** - Minimal Alpine-based Dockerfile
- **`examples/multi-stage.Dockerfile`** - Multi-stage build pattern
- **`examples/multi-platform.Dockerfile`** - Cross-platform build example
- **`examples/dockerignore`** - .dockerignore template

### External Resources

- [Docker Official Images](https://hub.docker.com/search?badges=official)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [BuildKit Documentation](https://docs.docker.com/build/buildkit/)
