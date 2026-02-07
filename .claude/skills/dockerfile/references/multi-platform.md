# Multi-Platform Builds

Guide for building Docker images that run on multiple platforms and architectures.

## Overview

Multi-platform builds create a single image that runs on different platforms:
- `linux/amd64` - x86-64 (most common)
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)
- `linux/arm/v7` - ARM 32-bit (Raspberry Pi)
- `windows/amd64` - Windows containers

Multi-platform images contain a **manifest list** pointing to platform-specific manifests. When pulling, Docker automatically selects the correct variant.

## Why Multi-Platform?

Containers share the host kernel, so code must be compatible with the host's architecture. Multi-platform builds solve this by packaging multiple variants into one image.

Benefits:
- Same image runs on x86-64 and ARM
- No emulation needed (when using native builders)
- Simplified deployment across heterogeneous infrastructure

## Prerequisites

### Choose an Image Store

**Option 1: containerd image store** (Recommended)
- Native support for multi-platform images
- Can push, pull, and load multi-platform images
- Enable in Docker Desktop settings or daemon configuration

**Option 2: Custom builder with docker-container driver**
- Build multi-platform without switching image stores
- Cannot load multi-platform images to local store
- Must push directly to registry: `docker build --push`

### Install QEMU (for emulation)

Required for cross-platform builds on Linux without native nodes:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

Verify installation:
```bash
cat /proc/sys/fs/binfmt_misc/qemu-*  # Should show 'F' flag
```

## Build Strategies

### 1. QEMU Emulation

Easiest to start, but slower for compute-heavy tasks:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
```

Pros:
- No special Dockerfile changes
- Works automatically

Cons:
- Much slower for compilation
- High CPU usage

### 2. Multiple Native Nodes

Best performance, uses actual hardware:

```bash
# Create multi-node builder
docker buildx create --name mybuilder node-amd64
docker buildx create --append --name mybuilder node-arm64

# Build using all nodes
docker buildx build --builder mybuilder --platform linux/amd64,linux/arm64 -t myapp:latest .
```

Pros:
- Native performance
- Handles complex cases

Cons:
- Requires multiple machines
- More infrastructure to manage

### 3. Cross-Compilation

Best for compiled languages with good cross-compilation support:

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

Pros:
- Fast native compilation
- Single builder

Cons:
- Requires language-specific cross-compilation setup
- Not all languages support it well

## Cross-Compilation Examples

### Go Application

Go has excellent cross-compilation support:

```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app
COPY . .
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o app .

FROM alpine:3.21
COPY --from=build /app/app /usr/local/bin/app
CMD ["app"]
```

Build:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t goapp .
```

### Using xx (Cross-Compilation Helpers)

The `xx` tool provides cross-compilation utilities:

```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx
FROM --platform=$BUILDPLATFORM golang:alpine AS build
COPY --from=xx / /
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

RUN xx-apk add --no-cache build-base
RUN xx-go --wrap
RUN CGO_ENABLED=0 go build -o app .

FROM alpine:3.21
COPY --from=build /app/app /usr/local/bin/app
CMD ["app"]
```

## Pre-Defined Build Arguments

BuildKit provides these for multi-platform builds:

| Argument | Description |
|----------|-------------|
| `BUILDPLATFORM` | Platform of the builder |
| `BUILDOS` | OS of the builder |
| `BUILDARCH` | Architecture of the builder |
| `BUILDVARIANT` | Variant of the builder |
| `TARGETPLATFORM` | Target platform |
| `TARGETOS` | Target OS |
| `TARGETARCH` | Target architecture |
| `TARGETVARIANT` | Target variant |

Example:
```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM alpine:3.21 AS build
ARG TARGETPLATFORM
RUN echo "Building for $TARGETPLATFORM" > /log

FROM alpine:3.21
COPY --from=build /log /log
```

## Docker Build Cloud

For managed multi-platform native builders:

```bash
# Create cloud builder
docker buildx create --driver cloud <ORG>/<BUILDER_NAME>

# Build using cloud
docker build \
  --builder cloud-<ORG>-<BUILDER_NAME> \
  --platform linux/amd64,linux/arm64 \
  --tag myapp:latest \
  --push .
```

Benefits:
- Managed ARM and x86 native builders
- Shared build cache
- No infrastructure to maintain
- Faster builds for CPU-intensive tasks

## Best Practices

### Use --platform for Build Stage

Pin build stage to builder platform to avoid emulation:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:alpine AS build
```

### Declare Build Arguments

Always declare target platform arguments:

```dockerfile
ARG TARGETOS
ARG TARGETARCH
```

### Test on Target Platforms

Verify images work on target platforms:

```bash
# Run on specific platform
docker run --rm --platform linux/arm64 myapp:latest

# Inspect manifest
docker buildx imagetools inspect myapp:latest
```

### Use Specific Tags for Base Images

Some image variants are platform-specific:

```dockerfile
FROM node:20-alpine  # Works for most platforms
```

Check base image documentation for platform support.

## Platform-Specific Considerations

### ARM Variants

- `linux/arm/v6` - Very old devices (Raspberry Pi Zero)
- `linux/arm/v7` - 32-bit ARM (Raspberry Pi 3/4)
- `linux/arm64` - 64-bit ARM (Apple Silicon, newer Pi)

### Windows Containers

Windows containers require Windows host:

```dockerfile
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
```

Windows containers have different base images and limitations.

### Architecture-Specific Packages

Some packages need architecture-specific installation:

```dockerfile
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    apk add package-armv8; \
    else \
    apk add package-x86_64; \
    fi
```

## Troubleshooting

### Verify Builder Supports Platforms

```bash
docker buildx inspect --bootstrap
```

Shows available platforms and builder configuration.

### Check Image Platforms

```bash
docker buildx imagetools inspect myapp:latest
```

Shows manifest list and all supported platforms.

### Test Specific Platform

```bash
docker run --rm --platform linux/arm64 myapp:latest uname -m
# Should show: aarch64
```

### Emulation Not Working

Ensure QEMU is properly installed:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

Verify registration:
```bash
ls -la /proc/sys/fs/binfmt_misc/qemu-*
```

### Slow Builds with Emulation

Consider:
1. Using cross-compilation instead
2. Setting up native build nodes
3. Using Docker Build Cloud

## Common Patterns

### Conditional Instructions

```dockerfile
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    apt-get install -y package-amd64; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    apt-get install -y package-arm64; \
    fi
```

### Platform-Specific Base Images

```dockerfile
FROM --platform=$BUILDPLATFORM alpine:3.21 AS base
RUN apk add --no-cache ca-certificates

FROM base AS build
# Build steps...

FROM alpine:3.21
COPY --from=build /app /app
```

### Multi-Stage with Different Platforms

```dockerfile
# Build on native platform
FROM --platform=$BUILDPLATFORM golang:alpine AS build
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o app .

# Final image for each target platform
FROM alpine:3.21
COPY --from=build /app /app
CMD ["/app"]
```
