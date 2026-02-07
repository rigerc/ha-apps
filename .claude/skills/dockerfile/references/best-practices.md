# Dockerfile Best Practices

Extended guide for creating production-ready, secure, and efficient Dockerfiles.

## Core Principles

### Multi-Stage Builds

Use multi-stage builds to separate build dependencies from runtime:

```dockerfile
# syntax=docker/dockerfile:1

# Build stage - includes compilers, build tools
FROM node:20-alpine AS build
WORKDIR /src
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage - only runtime dependencies
FROM alpine:3.21 AS production
WORKDIR /app
COPY --from=build /src/dist ./dist
CMD ["nginx", "-g", "daemon off;"]
```

Benefits:
- Smaller final images
- Reduced attack surface
- Clearer separation of concerns
- Better layer caching

### Create Reusable Stages

For multiple images with common components:

```dockerfile
# syntax=docker/dockerfile:1

FROM alpine:3.21 AS base
RUN apk add --no-cache ca-certificates

FROM base AS builder
RUN apk add --no-cache build-base
# ... build steps

FROM base AS runtime
COPY --from=builder /app /app
CMD ["/app/start"]
```

BuildKit builds the common `base` stage once.

## Base Image Selection

### Choose Trusted Sources

- **Docker Official Images** - Curated, documented, regularly updated
- **Verified Publisher** - High-quality images from verified organizations
- **Docker-Sponsored Open Source** - Maintained by sponsored projects

Look for badges on Docker Hub indicating these programs.

### Prefer Minimal Images

For production, choose minimal variants:

| Image | Standard | Slim/Minimal |
|-------|----------|-------------|
| Node | `node:20` | `node:20-alpine` or `node:20-slim` |
| Python | `python:3.12` | `python:3.12-slim` or `python:3.12-alpine` |
| Golang | `golang:1.23` | `golang:1.23-alpine` |
| Debian | `debian:bookworm` | `debian:bookworm-slim` |

Alpine images are under 6 MB but use musl libc which may have compatibility issues. Test thoroughly.

### Pin Base Image Versions

Tags are mutable. For reproducibility:

```dockerfile
# Using tag (mutable, can change)
FROM alpine:3.21

# Using digest (immutable, guaranteed)
FROM alpine:3.21@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
```

Use Docker Scout's "Up-to-Date Base Images" policy to monitor for updates when pinning to digests.

## Image Maintenance

### Rebuild Regularly

Images are immutable snapshots. Rebuild regularly to get:
- Security updates in base images
- Latest package versions
- Bug fixes and improvements

### Use --pull for Fresh Base Images

```bash
docker build --pull -t image:tag .
```

Forces checking for newer base images even if cached locally.

### Use --no-cache for Clean Builds

```bash
docker build --no-cache -t image:tag .
```

Disables build cache, ensuring all packages are freshly downloaded. Combine with `--pull` for completely fresh builds.

## Build Context Optimization

### Use .dockerignore

Exclude files from build context:

```dockerignore
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
*.md
!README/CHANGELOG.md
```

Benefits:
- Smaller build context
- Faster builds
- Avoid copying unnecessary files

Patterns use similar syntax to `.gitignore`:
- `*.md` - Exclude all .md files
- `!important.md` - Include this exception
- `**/secrets/*` - Exclude secrets directories anywhere

## Container Design

### Create Ephemeral Containers

Containers should be:
- Stateless
- Replaceable
- Reconfigurable via environment variables

Store state in volumes or external services, not in the container filesystem.

### Decouple Applications

Each container should have one primary concern. For example:
- Web application in one container
- Database in another container
- Cache in a third container

Use Docker networks for inter-container communication.

## Layer Optimization

### Leverage Build Cache

Order instructions from least to most frequently changing:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine

# 1. Rarely changes
WORKDIR /app

# 2. Changes when dependencies change
COPY package*.json ./
RUN npm ci --omit=dev

# 3. Changes frequently
COPY . .
RUN npm run build
```

Docker checks if a layer's instruction and inputs changed. If unchanged, it uses the cached layer.

### Chain RUN Commands

Combine related commands to reduce layers:

```dockerfile
# Good - single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Bad - multiple layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN rm -rf /var/lib/apt/lists/*
```

### Sort Multi-Line Arguments

Sort alphanumerically for maintenance:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    automake \
    build-essential \
    curl \
    git \
    libcap-dev \
    && rm -rf /var/lib/apt/lists/*
```

Prevents duplicate packages and makes updates easier to review.

## Instruction-Specific Best Practices

### FROM

Always use current official images:

```dockerfile
FROM alpine:3.21  # Official, minimal
FROM node:20-alpine  # Official with variant
```

### LABEL

Add metadata for organization and automation:

```dockerfile
LABEL maintainer="team@example.com"
LABEL version="1.0.0"
LABEL description="Web application container"
LABEL com.example.vendor="ACME Inc"
```

Use reverse domain notation for custom labels.

### RUN

For long or complex `RUN` statements, split across lines:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package-bar \
    package-baz \
    package-foo
```

Use backslash (`\`) for line continuation or here documents:

```dockerfile
RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends \
    package-bar \
    package-baz
rm -rf /var/lib/apt/lists/*
EOF
```

#### apt-get Best Practices

Always combine `update` and `install`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*
```

Why:
- Prevents caching issues
- Ensures latest package versions
- Cleans up cache to reduce image size

Never use `RUN apt-get update` separately.

#### Using Pipes in RUN

The shell only checks the exit code of the last command in a pipe. To fail on any error:

```dockerfile
# Good - fails on any error
RUN set -o pipefail && wget -O - https://site | wc -l > /number

# Bad - succeeds even if wget fails
RUN wget -O - https://site | wc -l > /number
```

For shells without `pipefail` (like dash), use exec form with bash:

```dockerfile
RUN ["/bin/bash", "-c", "set -o pipefail && wget -O - https://site | wc -l > /number"]
```

### CMD

Use exec form for services:

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

Use interactive shell for development images:

```dockerfile
CMD ["python"]
CMD ["perl", "-de0"]
```

Rarely use `CMD ["param", "param"]` with `ENTRYPOINT` unless users are familiar with it.

### EXPOSE

Use the standard, traditional port for the application:

```dockerfile
EXPOSE 80     # HTTP
EXPOSE 443    # HTTPS
EXPOSE 27017  # MongoDB
EXPOSE 5432   # PostgreSQL
```

This is documentation only. Use `-p` when running to publish ports.

### ENV

Use `ENV` to update `PATH` for installed software:

```dockerfile
ENV PATH="/usr/local/nginx/bin:${PATH}"
```

Use `ENV` for application-specific environment variables:

```dockerfile
ENV PGDATA=/var/lib/postgresql/data
```

Use `ENV` for version management:

```dockerfile
ENV NODE_VERSION=20.0.0
ENV ARCH=x64
RUN curl -SLO https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCH}.tar.gz
```

Each `ENV` creates a layer. For temporary variables, use:

```dockerfile
RUN export ADMIN_USER="mark" \
    && echo $ADMIN_USER > ./mark \
    && unset ADMIN_USER
```

### ADD vs COPY

Prefer `COPY` for local files:

```dockerfile
# Use for local files
COPY app.py /app/

# Use for remote URLs with auto-extraction
ADD https://example.com/file.tar.gz /usr/src/

# Use in multi-stage builds
COPY --from=build /src/dist /app/dist
```

For temporary files in `RUN`, use bind mounts:

```dockerfile
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    pip install --requirement /tmp/requirements.txt
```

### ENTRYPOINT

Use `ENTRYPOINT` for the main command, `CMD` for defaults:

```dockerfile
ENTRYPOINT ["s3cmd"]
CMD ["--help"]
```

This makes the image run like the `s3cmd` command:

```bash
docker run s3cmd              # Shows help
docker run s3cmd ls s3://bucket  # Lists bucket
```

Use with helper scripts for initialization:

```dockerfile
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["postgres"]
```

The script should use `exec` for the final command to receive signals properly.

### VOLUME

Expose any mutable or user-serviceable data:

```dockerfile
VOLUME /var/lib/postgresql/data
VOLUME ["/var/log/app", "/var/db/app"]
```

Use volumes for:
- Database storage
- Configuration files
- User uploads
- Logs

### USER

Create and use non-root users:

```dockerfile
RUN groupadd -r postgres && useradd --no-log-init -r -g postgres postgres
USER postgres
```

Assign explicit UID/GID when required:

```dockerfile
RUN groupadd -g 1000 appgroup && useradd -u 1000 -g appgroup appuser
USER appuser
```

Avoid `sudo` - has unpredictable TTY and signal handling. Use `gosu` instead:

```dockerfile
RUN gosu postgres postgres
```

Don't switch `USER` frequently - increases complexity.

### WORKDIR

Always use absolute paths:

```dockerfile
WORKDIR /app
```

Use `WORKDIR` instead of `RUN cd`:

```dockerfile
# Good
WORKDIR /app
RUN ./install.sh

# Bad - hard to read and maintain
RUN cd /app && ./install.sh
```

### ONBUILD

Use for images meant to be base images:

```dockerfile
ONBUILD COPY . /src
ONBUILD RUN npm install
```

Tag these images separately:

```dockerfile
ruby:1.9-onbuild
ruby:2.0-onbuild
```

Be careful with `ADD` or `COPY` in `ONBUILD` - fails if the child build context lacks the resource.

## Security Considerations

### Run as Non-Root

Always create and use a non-root user:

```dockerfile
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser
USER appuser
```

### Don't Install Unnecessary Packages

Avoid including tools "just in case":

```dockerfile
# Bad
RUN apt-get install -y vim emacs nano curl wget git

# Good - only what's needed
RUN apt-get install -y --no-install-recommends curl
```

### Use Specific Versions

Pin dependency versions to prevent unexpected changes:

```dockerfile
RUN pip install flask==3.0.*  # Pinned to 3.0.x
RUN npm install package@1.2.3  # Exact version
```

### Scan for Vulnerabilities

Use Docker Scout or similar tools:

```bash
docker scout cves image:tag
```

Integrate scanning into CI/CD pipeline.

## CI/CD Integration

### Build and Test in CI

Automatically build and test images when code changes:

```yaml
# GitHub Actions example
- name: Build image
  run: docker build -t app:${{ github.sha }} .

- name: Run tests
  run: docker run --rm app:${{ github.sha }} npm test
```

### Tag Strategies

Use meaningful tags:
- `latest` - Most recent build
- `v1.0.0` - Semantic version
- `abc123def` - Git commit SHA
- `feature-branch` - Feature branch name

## Performance Tips

1. **Use BuildKit** - Enabled by default in modern Docker
2. **Leverage layer cache** - Order instructions by change frequency
3. **Minimize layers** - Chain RUN commands
4. **Use .dockerignore** - Reduce build context size
5. **Multi-stage builds** - Separate build and runtime dependencies
6. **Parallel builds** - BuildKit executes independent stages in parallel
7. **Cache mounts** - Use `--mount=type=cache` for package managers

```dockerfile
# Cache mount example
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y package
```
